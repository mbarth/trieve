# Trieve Multi-Tenant Device Architecture Documentation

## Overview
This document outlines the recommended Trieve implementation for a multi-tenant IoT monitoring system with organization > device hierarchy for HVAC and oil & gas equipment.

## Architecture Design

### Hierarchy Structure
```
Trieve Organization (Company/Tenant)
├── Dataset (Device-001-Type)  
├── Dataset (Device-002-Type)
├── Dataset (Device-N-Type)
```

### Key Principles
- **1 Organization = 1 Company/Tenant**
- **1 Dataset = 1 Device** 
- **Complete data isolation per device**
- **No cross-device data contamination**

## API Configuration

### Base Configuration
- **API Endpoint:** `http://localhost:8090/api`
- **Authentication:** API Key based
- **Dataset Targeting:** Use `TR-Dataset` header

### Headers Required
```http
Authorization: Bearer YOUR_API_KEY
TR-Dataset: {specific_dataset_id}
Content-Type: application/json
```

## Core API Operations

### 1. Organization Management

#### Create Organization (Per Company/Tenant)
```http
POST /api/organization
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json

{
  "name": "HVAC Company A",
  "registration_enabled": false
}
```

**Response:**
```json
{
  "id": "org-uuid-here",
  "name": "HVAC Company A",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### 2. Dataset Management (Per Device)

#### Create Dataset for Device
```http
POST /api/dataset
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json

{
  "organization_id": "org-uuid-here",
  "dataset_name": "Device-001-Boiler-Manuals",
  "description": "PDF manuals and documentation for HVAC Device 001 Boiler Unit",
  "server_configuration": {
    "EMBEDDING_SIZE": 1536,
    "DISTANCE_METRIC": "cosine"
  }
}
```

**Response:**
```json
{
  "dataset": {
    "id": "dataset-uuid-here", 
    "name": "Device-001-Boiler-Manuals",
    "organization_id": "org-uuid-here",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### 3. Document Upload (Device-Specific PDFs)

#### Upload PDF to Device Dataset
```http
POST /api/file
Authorization: Bearer YOUR_API_KEY
TR-Dataset: {device_dataset_id}
Content-Type: multipart/form-data

Form Data:
- file: {PDF_FILE}
- file_name: "Device-001-Installation-Manual.pdf"
- description: "Installation and maintenance manual for Device 001"
- tag_set: ["manual", "installation", "device-001", "boiler"]
```

**Response:**
```json
{
  "file": {
    "id": "file-uuid-here",
    "file_name": "Device-001-Installation-Manual.pdf", 
    "size": 2048576,
    "dataset_id": "dataset-uuid-here"
  }
}
```

### 4. RAG Search (Device-Specific)

#### Search Within Device Dataset
```http
POST /api/chunk/search
Authorization: Bearer YOUR_API_KEY
TR-Dataset: {device_dataset_id}
Content-Type: application/json

{
  "query": "temperature sensor calibration procedure",
  "search_type": "hybrid",
  "page": 1,
  "page_size": 10,
  "score_threshold": 0.7,
  "highlight_results": true,
  "highlight_delimiters": ["<mark>", "</mark>"]
}
```

**Response:**
```json
{
  "chunks": [
    {
      "chunk": {
        "id": "chunk-uuid-here",
        "content": "To calibrate the temperature sensor on the boiler unit...",
        "metadata": {
          "file_name": "Device-001-Installation-Manual.pdf",
          "page_number": 42
        }
      },
      "score": 0.89
    }
  ],
  "total_chunk_pages": 1
}
```

### 5. RAG Chat Completion

#### Generate RAG Response for Device
```http
POST /api/message
Authorization: Bearer YOUR_API_KEY
TR-Dataset: {device_dataset_id}
Content-Type: application/json

{
  "topic_id": "optional-conversation-uuid",
  "new_message_content": "The temperature sensor on our HVAC unit is reading incorrectly. How do I calibrate it?",
  "search_query": "temperature sensor calibration",
  "search_type": "hybrid",
  "page_size": 5,
  "context_options": {
    "score_threshold": 0.7
  }
}
```

**Response:**
```json
{
  "message": "Based on your device's manual, to calibrate the temperature sensor on your HVAC unit: [detailed response using only Device-001 documentation]",
  "citations": [
    {
      "document": "Device-001-Installation-Manual.pdf",
      "page": 42,
      "content": "Sensor calibration procedure..."
    }
  ]
}
```

## Implementation Flow for Cloud Pipeline Handler

### 1. Tenant/Organization Mapping
```
Your System          →  Trieve
company_id/tenant_id  →  organization_id
```

### 2. Device/Dataset Mapping  
```
Your System    →  Trieve
device_id      →  dataset_id
```

### 3. Recommended Database Schema (Your Side)
```sql
CREATE TABLE trieve_mappings (
    id SERIAL PRIMARY KEY,
    company_id VARCHAR(255) NOT NULL,
    device_id VARCHAR(255) NOT NULL, 
    trieve_org_id UUID NOT NULL,
    trieve_dataset_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(company_id, device_id)
);
```

### 4. Sensor Alert → RAG Flow
```
1. Sensor Alert → Edge Device
2. Edge Device → Cloud Pipeline Handler 
   POST /alert {company_id, device_id, sensor_data, alert_type}

3. Cloud Pipeline Handler:
   a) Lookup: device_id → trieve_dataset_id
   b) Query Trieve for relevant docs
   c) Generate enhanced alert with contextual info
   d) Send to dashboard/notification system
```

## Environment Configuration

### Required Environment Variables
```bash
# From your .env file
TRIEVE_API_URL=http://localhost:8090/api
TRIEVE_API_KEY=your_api_key_here
```

## Error Handling

### Common Error Responses
```json
// Dataset not found
{
  "error": "Dataset not found",
  "status": 404
}

// Insufficient permissions
{
  "error": "Unauthorized access to dataset", 
  "status": 403
}

// Invalid API key
{
  "error": "Invalid or missing API key",
  "status": 401
}
```

## Performance Considerations

### Recommended Limits
- **Max file size:** 100MB per PDF
- **Max chunks per search:** 20 
- **Search timeout:** 30 seconds
- **Concurrent searches per dataset:** 50

### Optimization Tips
1. **Tag PDFs** with device metadata for better filtering
2. **Use hybrid search** for best accuracy
3. **Set score thresholds** (0.7+) to filter low-quality results
4. **Cache frequent searches** to reduce API calls
5. **Batch upload** PDFs when possible

## Security Best Practices

### API Key Management
- Use separate API keys per environment (dev/staging/prod)
- Rotate API keys regularly
- Store API keys in secure environment variables
- Never log API keys

### Data Isolation Verification
```bash
# Test that Device-001 searches don't return Device-002 results
curl -X POST "http://localhost:8090/api/chunk/search" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "TR-Dataset: device-001-dataset-id" \
  -d '{"query": "device-002 specific term"}'

# Should return no results or very low scores
```

## Testing Your Implementation

### Validation Checklist
- [ ] Each device has its own unique dataset ID
- [ ] Searches against Device-001 dataset only return Device-001 docs
- [ ] Organization isolation works (Company A can't see Company B data)
- [ ] API key permissions are properly scoped
- [ ] RAG responses only cite device-specific documentation
- [ ] File uploads go to correct device dataset
- [ ] Error handling works for invalid dataset IDs

### Sample Test Script
```bash
#!/bin/bash
# Test device isolation

DEVICE_001_DATASET="dataset-uuid-001"
DEVICE_002_DATASET="dataset-uuid-002" 
API_KEY="your-api-key"

echo "Testing Device 001 isolation..."
curl -X POST "http://localhost:8090/api/chunk/search" \
  -H "Authorization: Bearer $API_KEY" \
  -H "TR-Dataset: $DEVICE_001_DATASET" \
  -d '{"query": "device specific test query", "page_size": 5}'

echo "Testing Device 002 isolation..."  
curl -X POST "http://localhost:8090/api/chunk/search" \
  -H "Authorization: Bearer $API_KEY" \
  -H "TR-Dataset: $DEVICE_002_DATASET" \
  -d '{"query": "device specific test query", "page_size": 5}'
```

## Troubleshooting

### Common Issues
1. **Cross-device contamination:** Verify TR-Dataset header is correctly set
2. **Missing results:** Check score_threshold isn't too high
3. **Slow searches:** Reduce page_size or add more specific queries
4. **Upload failures:** Verify file size and format restrictions

### Debug Logging
```http
# Add debug parameter to search requests
POST /api/chunk/search
{
  "query": "test query",
  "search_type": "hybrid", 
  "debug": true
}
```

---

## Summary

This architecture ensures:
✅ Complete device data isolation  
✅ Scalable multi-tenancy  
✅ Fast, device-specific RAG responses  
✅ No cross-contamination between devices  
✅ Simple mapping from your system to Trieve  

Use this documentation to verify your cloud-pipeline-handler implementation aligns with these patterns.