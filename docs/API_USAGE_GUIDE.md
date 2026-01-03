# Trieve API Usage Guide for cloud-pipeline-handler Integration

This guide provides complete API documentation for operations used in the cloud-pipeline-handler RAG integration.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [Required Headers](#required-headers)
- [API Endpoints](#api-endpoints)
  - [Organization Management](#organization-management)
  - [Dataset Management](#dataset-management)
  - [File Upload](#file-upload)
  - [Search Operations](#search-operations)
  - [Chunk Management](#chunk-management)
- [Error Handling](#error-handling)
- [Rate Limits and Quotas](#rate-limits-and-quotas)
- [Best Practices](#best-practices)

## Overview

**Base URL**: `http://localhost:8090/api` (local) or `https://api.trieve.ai/api` (cloud)

**API Version**: v1 and v2 supported (v2 recommended for new integrations)

**Authentication**: Bearer token (API Key)

**Content Type**: `application/json`

## Authentication

All API requests require an API key obtained from the Trieve dashboard.

### Getting an API Key

1. Log into Trieve dashboard: http://localhost:5173
2. Navigate to **Settings** > **API Keys**
3. Click **Create API Key**
4. Select permission level: **Owner** or **Admin** (required for dataset creation)
5. Copy the generated key (starts with `tr_`)

### Using the API Key

Include in the `Authorization` header:

```
Authorization: Bearer tr_your_api_key_here
```

## Required Headers

### Standard Headers

```http
Authorization: Bearer tr_your_api_key_here
Content-Type: application/json
```

### Organization Header

For organization-scoped operations:

```http
TR-Organization: 00000000-0000-0000-0000-000000000000
```

The `TR-Organization` header specifies which organization context to use. Get this UUID from the dashboard under **Settings** > **Organization**.

### Dataset Header

For dataset-scoped operations:

```http
TR-Dataset: 00000000-0000-0000-0000-000000000000
```

The `TR-Dataset` header specifies which dataset to operate on. This can be either:
- Dataset ID (UUID)
- Dataset tracking_id (if set during creation)

## API Endpoints

### Organization Management

#### Get Organization Details

```http
GET /api/organization/{organization_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
```

**Response:**
```json
{
  "id": "00000000-0000-0000-0000-000000000000",
  "name": "My Organization",
  "created_at": "2024-01-01T00:00:00.000Z"
}
```

### Dataset Management

#### Create Dataset

```http
POST /api/dataset
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Organization: 00000000-0000-0000-0000-000000000000
Content-Type: application/json
```

**Request Body:**
```json
{
  "dataset_name": "org-123e4567-e89b-12d3-a456-426614174000-device-pump-001",
  "tracking_id": "device-pump-001",
  "server_configuration": {
    "FULLTEXT_ENABLED": true,
    "SEMANTIC_ENABLED": true,
    "BM25_ENABLED": true,
    "EMBEDDING_SIZE": 1536,
    "DISTANCE_METRIC": "cosine",
    "EMBEDDING_MODEL_NAME": "text-embedding-3-small",
    "LLM_DEFAULT_MODEL": "gpt-3.5-turbo"
  }
}
```

**Response:**
```json
{
  "id": "dataset-uuid-here",
  "name": "org-123e4567-e89b-12d3-a456-426614174000-device-pump-001",
  "organization_id": "00000000-0000-0000-0000-000000000000",
  "tracking_id": "device-pump-001",
  "created_at": "2024-01-01T00:00:00.000Z",
  "server_configuration": { ... }
}
```

**Important Notes:**
- `dataset_name`: User-friendly name, can include organization and device IDs
- `tracking_id`: Optional but recommended for easy lookup (use device_id)
- `server_configuration`: Optional, defaults to sensible values if omitted

#### Get Dataset by ID

```http
GET /api/dataset/{dataset_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Organization: 00000000-0000-0000-0000-000000000000
```

**Response:**
```json
{
  "id": "dataset-uuid",
  "name": "org-...-device-pump-001",
  "organization_id": "org-uuid",
  "tracking_id": "device-pump-001",
  "created_at": "2024-01-01T00:00:00.000Z"
}
```

#### Get Dataset by Tracking ID

```http
GET /api/dataset/tracking_id/{tracking_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Organization: 00000000-0000-0000-0000-000000000000
```

**Response:** Same as Get Dataset by ID

#### List Datasets in Organization

```http
GET /api/dataset/organization/{organization_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Organization: 00000000-0000-0000-0000-000000000000
```

**Response:**
```json
[
  {
    "id": "dataset-uuid-1",
    "name": "org-...-device-pump-001",
    "tracking_id": "device-pump-001"
  },
  {
    "id": "dataset-uuid-2",
    "name": "org-...-device-compressor-002",
    "tracking_id": "device-compressor-002"
  }
]
```

#### Delete Dataset

```http
DELETE /api/dataset/{dataset_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Organization: 00000000-0000-0000-0000-000000000000
```

**Response:** `204 No Content`

### File Upload

#### Upload File (PDF with Auto-Chunking)

```http
POST /api/file
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
Content-Type: application/json
```

**Request Body:**
```json
{
  "base64_file": "JVBERi0xLjQKJeLjz9MKMyAwIG9iago8PC9GaWx0ZXIvRmxhdGVEZWNvZGUvTGVuZ3RoIDQ5Nj4+c3RyZWFtCnicrZVPb9swDMXv...",
  "file_name": "pump-maintenance-manual.pdf",
  "tag_set": ["device:pump-001", "manual", "maintenance"],
  "description": "Maintenance manual for industrial pump model XYZ-2000",
  "link": "https://example.com/manuals/pump-xyz-2000",
  "metadata": {
    "device_id": "pump-001",
    "equipment_type": "pump",
    "model": "XYZ-2000",
    "uploaded_by": "system"
  },
  "target_splits_per_chunk": 20,
  "use_pdf2md_ocr": false
}
```

**Field Descriptions:**

- `base64_file` **(required)**: Base64-encoded file content
  - Trieve accepts both standard base64 and base64url encoding
  - Your Rust code can use standard base64 encoding

- `file_name` **(required)**: Original filename with extension

- `tag_set` (optional): Array of tags for filtering
  - Tags create HNSW indices for fast filtering
  - Use for: device IDs, equipment types, categories

- `description` (optional): Human-readable description

- `link` (optional): URL reference to original document

- `metadata` (optional): Arbitrary JSON metadata
  - Filterable but slower than tags
  - Use for: additional context, complex filtering

- `target_splits_per_chunk` (optional, default: 20): Target number of text splits per chunk

- `use_pdf2md_ocr` (optional, default: false): Use vision LLM for PDF to Markdown conversion
  - `false`: Uses Apache Tika (faster, cheaper)
  - `true`: Uses vision LLM (better quality, slower, more expensive)

**Response:**
```json
{
  "file_metadata": {
    "id": "file-uuid",
    "file_name": "pump-maintenance-manual.pdf",
    "size": 2048576,
    "tag_set": ["device:pump-001", "manual", "maintenance"],
    "metadata": { "device_id": "pump-001" },
    "created_at": "2024-01-01T00:00:00.000Z"
  }
}
```

**Important Notes:**

1. **Base64 Encoding**: Standard base64 is accepted. Server handles conversion.

2. **File Processing**: File processing is asynchronous
   - API returns immediately with file metadata
   - Chunks are created in the background (file-worker)
   - Check chunk creation: `GET /api/file/{file_id}`

3. **File Size Limits**: Check organization plan limits
   - Default: typically 10MB per file
   - Can be configured per organization

#### Get File Details

```http
GET /api/file/{file_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
```

**Response:**
```json
{
  "id": "file-uuid",
  "file_name": "pump-maintenance-manual.pdf",
  "size": 2048576,
  "tag_set": ["device:pump-001"],
  "created_at": "2024-01-01T00:00:00.000Z",
  "chunks_created": 42,
  "processing_status": "completed"
}
```

#### List Files in Dataset

```http
GET /api/dataset/files/{dataset_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
```

**Query Parameters:**
- `page` (optional, default: 1): Page number
- `page_size` (optional, default: 10): Results per page

**Response:**
```json
{
  "files": [
    {
      "id": "file-uuid-1",
      "file_name": "pump-manual.pdf",
      "created_at": "2024-01-01T00:00:00.000Z"
    }
  ],
  "total_pages": 5
}
```

#### Delete File

```http
DELETE /api/file/{file_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
X-API-Version: v2
```

**Path Parameters:**
- `file_id` **(required)**: The UUID of the file to delete (from upload response)

**Response:** `204 No Content`

**Important Notes:**
- Deleting a file also deletes all associated chunks automatically
- You must store the `file_id` from the upload response to enable deletion
- The file_id is a UUID, not the filename

**Example:**
```bash
# Delete a file using the file_id from upload
curl -X DELETE "http://localhost:8090/api/file/123e4567-e89b-12d3-a456-426614174000" \
  -H "Authorization: Bearer tr_your_api_key" \
  -H "TR-Dataset: device-pump-001" \
  -H "X-API-Version: v2"
```

### Search Operations

#### Semantic Search (Raw Results)

```http
POST /api/chunk/search
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
Content-Type: application/json
```

**Request Body (Basic):**
```json
{
  "query": "How to maintain pump seals?",
  "search_type": "semantic",
  "page": 1,
  "page_size": 3,
  "score_threshold": 0.25
}
```

**Request Body (Advanced):**
```json
{
  "query": "How to maintain pump seals?",
  "search_type": "hybrid",
  "page": 1,
  "page_size": 3,
  "score_threshold": 0.25,
  "filters": {
    "must": [
      {
        "field": "tag_set",
        "match_any": ["device:pump-001", "manual"]
      }
    ]
  },
  "highlight_options": {
    "highlight_results": true,
    "highlight_delimiters": ["<mark>", "</mark>"]
  },
  "slim_chunks": false
}
```

**Field Descriptions:**

- `query` **(required)**: Search query string

- `search_type` **(required)**: Search method
  - `"semantic"`: Dense vector similarity (best for semantic understanding)
  - `"fulltext"`: SPLADE sparse vector (best for keyword matching)
  - `"hybrid"`: Combines semantic + fulltext with re-ranking (recommended)
  - `"bm25"`: Traditional BM25 keyword search

- `page` (optional, default: 1): Result page number

- `page_size` (optional, default: 10): Results per page

- `score_threshold` (optional): Minimum relevance score
  - For cosine distance: 0.0 (dissimilar) to 1.0 (identical)
  - Recommended for RAG: 0.2 - 0.3
  - Your implementation uses: 0.25 ✓

- `filters` (optional): Advanced filtering
  - `must`: All conditions must match (AND)
  - `should`: At least one condition must match (OR)
  - `must_not`: Exclude matching items

- `highlight_options` (optional): Enable result highlighting

- `slim_chunks` (optional, default: false): Exclude chunk content (faster)

**Response:**
```json
{
  "chunks": [
    {
      "chunk": {
        "id": "chunk-uuid-1",
        "chunk_html": "To maintain <mark>pump seals</mark>, follow these steps...",
        "metadata": {
          "device_id": "pump-001"
        },
        "tag_set": ["device:pump-001", "manual"],
        "tracking_id": "chunk-tracking-1",
        "created_at": "2024-01-01T00:00:00.000Z"
      },
      "score": 0.87
    },
    {
      "chunk": {
        "id": "chunk-uuid-2",
        "chunk_html": "Regular <mark>seal</mark> inspection prevents leaks...",
        "metadata": {},
        "tag_set": ["device:pump-001"],
        "tracking_id": null,
        "created_at": "2024-01-01T00:00:00.000Z"
      },
      "score": 0.76
    }
  ],
  "total_pages": 1
}
```

**Response Structure (API v1):**

The response structure depends on the API version:

- **V1 (default for older orgs)**: Returns `{ score_chunks: [...] }`
- **V2 (default for new orgs)**: Returns `{ chunks: [...] }`

Specify version with header:
```http
X-API-Version: v2
```

**Scoring:**

- Higher scores = more relevant (for cosine similarity)
- Score range: 0.0 to 1.0 for cosine distance
- Recommendation: Filter results with `score_threshold` >= 0.25

#### RAG Completion (LLM-Generated Answers)

For getting complete answers instead of raw chunks (similar to AnythingLLM):

```http
POST /api/chunk/generate
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
Content-Type: application/json
X-API-Version: v2
```

**Request Body:**
```json
{
  "query": "How do I maintain pump seals?",
  "search_type": "hybrid",
  "page_size": 5,
  "score_threshold": 0.25,
  "llm_options": {
    "model": "gpt-3.5-turbo",
    "temperature": 0.1,
    "max_tokens": 1000,
    "system_message": "You are an expert industrial equipment maintenance technician. Answer questions based only on the provided equipment manual context. Be specific and actionable."
  },
  "highlight_results": true
}
```

**Field Descriptions:**

- `query` **(required)**: The question to ask
- `search_type` **(required)**: Same as search endpoint (`"hybrid"` recommended)
- `page_size` (optional, default: 10): Number of chunks to include in LLM context
- `score_threshold` (optional): Filter chunks before sending to LLM
- `llm_options` **(required)**: LLM configuration
  - `model`: LLM model to use (e.g., "gpt-3.5-turbo", "gpt-4")
  - `temperature`: Creativity level (0.0-1.0, recommend 0.1 for factual answers)
  - `max_tokens`: Maximum response length
  - `system_message`: Instructions for the LLM
- `highlight_results` (optional, default: false): Return highlighted chunks

**Response:**
```json
{
  "completion": "To maintain pump seals, follow these steps:\n\n1. Turn off the pump and relieve all pressure in the system\n2. Remove the seal housing carefully to avoid damage\n3. Inspect the seals for signs of wear, cracking, or deterioration\n4. Clean the seal housing thoroughly\n5. Install new seals using proper lubricant\n6. Reassemble following torque specifications\n\nRegular seal inspection should be performed every 3 months or 500 operating hours, whichever comes first.",
  "chunks": [
    {
      "chunk": {
        "id": "chunk-uuid",
        "chunk_html": "Pump seal maintenance procedures...",
        "metadata": {"device_id": "pump-001"},
        "tag_set": ["device:pump-001", "maintenance"]
      },
      "score": 0.89
    }
  ]
}
```

**Key Benefits:**
- **Complete answers**: Get formatted responses ready for users
- **Contextual**: LLM answers based on relevant manual content
- **Customizable**: Control LLM behavior with system messages
- **Sources included**: See which chunks informed the answer

**Use Cases:**
- **User-facing chat**: Direct answers for equipment operators
- **Technical support**: Detailed maintenance instructions
- **Troubleshooting**: Step-by-step problem resolution

### Chunk Management

#### Create Chunk Directly

While files are auto-chunked, you can also create chunks directly:

```http
POST /api/chunk
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
Content-Type: application/json
```

**Request Body:**
```json
{
  "chunk_html": "<p>This is the chunk content. Can be HTML or plain text.</p>",
  "link": "https://example.com/source",
  "tag_set": ["device:pump-001", "custom"],
  "metadata": {
    "source": "manual-page-5",
    "device_id": "pump-001"
  },
  "tracking_id": "custom-chunk-1"
}
```

**Response:**
```json
{
  "chunk_metadata": {
    "id": "chunk-uuid",
    "chunk_html": "<p>This is the chunk content...</p>",
    "tag_set": ["device:pump-001", "custom"],
    "created_at": "2024-01-01T00:00:00.000Z"
  }
}
```

#### Update Chunk

```http
PUT /api/chunk
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
Content-Type: application/json
```

**Request Body:**
```json
{
  "chunk_id": "chunk-uuid",
  "chunk_html": "<p>Updated content</p>",
  "metadata": {
    "updated": true
  }
}
```

#### Delete Chunk

```http
DELETE /api/chunk/{chunk_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
```

**Response:** `204 No Content`

#### Get Chunk by ID

```http
GET /api/chunk/{chunk_id}
```

**Headers:**
```http
Authorization: Bearer tr_your_api_key
TR-Dataset: dataset-uuid-or-tracking-id
```

**Response:**
```json
{
  "id": "chunk-uuid",
  "chunk_html": "Chunk content here",
  "metadata": {},
  "tag_set": ["device:pump-001"],
  "created_at": "2024-01-01T00:00:00.000Z"
}
```

## Error Handling

### HTTP Status Codes

- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `204 No Content`: Successful deletion
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Missing or invalid API key
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource doesn't exist
- `409 Conflict`: Resource conflict (e.g., duplicate tracking_id)
- `413 Payload Too Large`: File size exceeds limit
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

### Error Response Format

```json
{
  "message": "Error description here",
  "error_type": "BadRequest",
  "details": "Additional context if available"
}
```

### Common Errors

#### Invalid API Key

```json
{
  "message": "Unauthorized: Invalid API key"
}
```

**Solution**: Verify API key is correct and has not been revoked.

#### Dataset Not Found

```json
{
  "message": "Dataset not found"
}
```

**Solution**: Verify `TR-Dataset` header contains correct dataset ID or tracking_id.

#### Base64 Decode Error

```json
{
  "message": "Could not decode base64 file"
}
```

**Solution**: Ensure base64 encoding is valid. Both standard and base64url formats are accepted.

#### Score Threshold Error

No error returned, but you may get fewer results than expected.

**Solution**: Lower `score_threshold` if getting no results.

#### File Too Large

```json
{
  "message": "File size exceeds maximum allowed size"
}
```

**Solution**: Check organization plan limits or chunk the file before upload.

## Rate Limits and Quotas

### Self-Hosted Trieve

- **No rate limits by default** when `UNLIMITED=true` in `.env`
- Can be configured via environment variables if needed

### Cloud Trieve (api.trieve.ai)

- **Rate limits** depend on plan tier
- Typical limits:
  - Free tier: 100 requests/minute
  - Pro tier: 1000 requests/minute
  - Enterprise: Custom limits

### Quota Limits

Check your organization's quotas:
- **Datasets per organization**
- **Chunks per dataset**
- **File size limits**
- **Storage limits**

Quotas are plan-dependent and configurable.

## Best Practices

### 1. Use Tracking IDs

Always set `tracking_id` for datasets and important chunks:

```json
{
  "dataset_name": "org-...-device-pump-001",
  "tracking_id": "device-pump-001"
}
```

Benefits:
- Easier lookups without remembering UUIDs
- Idempotent operations
- Better error messages

### 2. Implement Idempotent Dataset Creation

Check if dataset exists before creating:

```rust
// Pseudocode
async fn get_or_create_dataset(device_id: &str) -> Result<Dataset> {
    let tracking_id = format!("device-{}", device_id);

    // Try to get existing dataset
    match get_dataset_by_tracking_id(&tracking_id).await {
        Ok(dataset) => Ok(dataset),
        Err(_) => {
            // Create new dataset
            create_dataset(&tracking_id).await
        }
    }
}
```

### 3. Use Appropriate Search Types

- **Semantic search**: Best for natural language queries
  - "How do I fix a leak?"
  - "What causes overheating?"

- **Hybrid search**: Best for mixed queries (recommended)
  - Combines semantic understanding with keyword matching
  - Re-ranks with cross-encoder for best results

- **Fulltext/BM25**: Best for exact keyword matching
  - "error code E401"
  - "model XYZ-2000"

### 4. Set Reasonable Score Thresholds

For RAG applications:
- `0.2 - 0.3`: Good balance (recommended starting point)
- `0.4+`: High precision, may miss relevant results
- `0.1 - 0.2`: Higher recall, may include less relevant results

Your implementation uses `0.25` ✓ - this is a good default.

### 5. Use Tags for Device Isolation

Tags create optimized indices for fast filtering:

```json
{
  "tag_set": [
    "device:pump-001",
    "type:manual",
    "category:maintenance"
  ]
}
```

Then filter searches:

```json
{
  "query": "seal replacement",
  "filters": {
    "must": [
      { "field": "tag_set", "match_any": ["device:pump-001"] }
    ]
  }
}
```

### 6. Handle Async File Processing

File uploads return immediately, but processing happens asynchronously:

```rust
// 1. Upload file
let file_response = upload_file(pdf_data).await?;

// 2. Poll for completion (optional)
loop {
    let file_details = get_file(file_response.id).await?;
    if file_details.processing_status == "completed" {
        break;
    }
    sleep(Duration::from_secs(5)).await;
}

// 3. Query chunks
let results = search("maintenance procedures").await?;
```

### 7. Error Handling and Retries

Implement exponential backoff for transient errors:

```rust
for attempt in 1..=3 {
    match search_chunks(query).await {
        Ok(result) => return Ok(result),
        Err(e) if e.is_retryable() => {
            sleep(Duration::from_secs(2_u64.pow(attempt))).await;
            continue;
        }
        Err(e) => return Err(e),
    }
}
```

### 8. Batch Operations

When uploading multiple files, upload in parallel (with concurrency limits):

```rust
use futures::stream::{self, StreamExt};

let files = vec![file1, file2, file3];
let results: Vec<_> = stream::iter(files)
    .map(|file| upload_file(file))
    .buffer_unordered(5) // Max 5 concurrent uploads
    .collect()
    .await;
```

### 9. Monitor Chunk Creation

After bulk uploads, verify chunks were created:

```rust
// Get dataset statistics
let stats = get_dataset_usage(dataset_id).await?;
println!("Total chunks: {}", stats.chunk_count);
```

### 10. Clean Up Test Data

For development/testing, clean up old datasets:

```rust
// List all datasets
let datasets = list_datasets(org_id).await?;

// Delete test datasets
for dataset in datasets {
    if dataset.name.starts_with("test-") {
        delete_dataset(dataset.id).await?;
    }
}
```

## API Verification Checklist

Use this checklist to verify your cloud-pipeline-handler implementation:

- [ ] **Dataset Creation**: Can create datasets with org-device naming
- [ ] **Dataset Lookup**: Can retrieve datasets by tracking_id
- [ ] **File Upload**: Can upload base64-encoded PDFs
- [ ] **Async Handling**: Handles async chunk creation properly
- [ ] **Search**: Can search with score_threshold filtering
- [ ] **Result Parsing**: Correctly parses search response structure
- [ ] **Error Handling**: Handles API errors gracefully
- [ ] **Headers**: Correctly sets Authorization, TR-Organization, TR-Dataset
- [ ] **Device Isolation**: Each device has separate dataset
- [ ] **Multi-tenant**: Multiple orgs can coexist

## Example: Complete Workflow

```bash
# 1. Create dataset
curl -X POST "http://localhost:8090/api/dataset" \
  -H "Authorization: Bearer tr_YOUR_KEY" \
  -H "TR-Organization: YOUR_ORG_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "dataset_name": "org-test-device-pump-001",
    "tracking_id": "device-pump-001"
  }'

# Response: { "id": "DATASET_ID", ... }

# 2. Upload PDF
curl -X POST "http://localhost:8090/api/file" \
  -H "Authorization: Bearer tr_YOUR_KEY" \
  -H "TR-Dataset: device-pump-001" \
  -H "Content-Type: application/json" \
  -d '{
    "base64_file": "'$(base64 -w 0 manual.pdf)'",
    "file_name": "pump-manual.pdf",
    "tag_set": ["device:pump-001"]
  }'

# Response: { "file_metadata": { "id": "FILE_ID", ... } }

# 3. Wait for processing (5-30 seconds typically)
sleep 30

# 4. Search
curl -X POST "http://localhost:8090/api/chunk/search" \
  -H "Authorization: Bearer tr_YOUR_KEY" \
  -H "TR-Dataset: device-pump-001" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "seal maintenance",
    "search_type": "hybrid",
    "page_size": 3,
    "score_threshold": 0.25
  }'

# Response: { "chunks": [ { "chunk": {...}, "score": 0.87 }, ... ] }
```

## Additional Resources

- **Interactive API Docs**: http://localhost:8090/redoc (when running locally)
- **OpenAPI Spec**: http://localhost:8090/openapi.json
- **Trieve Docs**: https://docs.trieve.ai
- **TypeScript SDK**: https://github.com/devflowinc/trieve/tree/main/clients/ts-sdk
- **Python SDK**: https://github.com/devflowinc/trieve-py-client
