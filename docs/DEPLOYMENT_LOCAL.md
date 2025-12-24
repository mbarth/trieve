# Trieve Local Deployment Guide

This guide provides step-by-step instructions for deploying Trieve locally for development and testing purposes, specifically tailored for the cloud-pipeline-handler RAG integration.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Organization and API Key Setup](#organization-and-api-key-setup)
- [Configuration for Your Use Case](#configuration-for-your-use-case)
- [Health Checks and Verification](#health-checks-and-verification)
- [Troubleshooting](#troubleshooting)
- [Resource Requirements](#resource-requirements)

## Overview

Trieve is a complete search, recommendations, and RAG infrastructure platform. For your cloud-pipeline-handler integration, you'll be using:

- **Multiple Organizations**: Isolate data by customer organization
- **Multiple Datasets per Organization**: One dataset per device (e.g., `org-{uuid}-device-{device_id}`)
- **PDF File Upload with Auto-Chunking**: Upload equipment manuals that are automatically chunked
- **Semantic Search**: Query device-specific manuals with relevance scoring

## Prerequisites

### System Requirements

- **CPU**: 4+ cores recommended (2 minimum)
- **RAM**: 16GB recommended (8GB minimum)
- **Disk**: 20GB+ free space
- **OS**: Linux, macOS, or Windows with WSL2

### Required Software

1. **Docker** (20.10+) and **Docker Compose** (v2.0+)
   ```bash
   docker --version
   docker compose version
   ```

2. **Git**
   ```bash
   git --version
   ```

3. **OpenAI API Key** (or compatible LLM API)
   - Get from: https://platform.openai.com/api-keys
   - Alternative: Use OpenRouter, Groq, or local LLM endpoints

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/devflowinc/trieve.git
cd trieve

# 2. Configure environment
cp .env.example .env

# 3. Edit .env file - REQUIRED CHANGES:
nano .env  # or your preferred editor

# Set these values:
# KC_PROXY="none"  # For local development
# OPENAI_API_KEY="sk-your-actual-key-here"
# LLM_API_KEY="sk-your-actual-key-here"

# 4. Start Trieve
docker compose up -d

# 5. Wait for services to be healthy (5-10 minutes)
docker compose ps

# 6. Verify it's running
curl http://localhost:8090/api/health
```

## Detailed Setup

### Step 1: Clone and Configure

```bash
# Clone Trieve repository
git clone https://github.com/devflowinc/trieve.git
cd trieve

# Copy environment template
cp .env.example .env
```

### Step 2: Edit Environment Variables

Open `.env` in your editor and configure the following:

#### Required Changes

```bash
# Local development setting (CRITICAL)
KC_PROXY="none"  # Change from "edge" to "none"

# OpenAI API Key (REQUIRED for embeddings and LLM)
OPENAI_API_KEY="sk-your-actual-openai-api-key"
LLM_API_KEY="sk-your-actual-openai-api-key"
```

#### Optional But Recommended

```bash
# Change default passwords for security
REDIS_PASSWORD="your-secure-redis-password"
QDRANT_API_KEY="your-secure-qdrant-key"

# Admin API key for administrative operations
ADMIN_API_KEY="your-admin-api-key"

# MinIO (S3) credentials for file storage
MINIO_ROOT_USER="your-minio-user"
MINIO_ROOT_PASSWORD="your-minio-password"
S3_ACCESS_KEY="your-s3-access-key"
S3_SECRET_KEY="your-s3-secret-key"
```

#### Service Endpoints (Default - Usually No Changes Needed)

```bash
BASE_SERVER_URL="http://localhost:8090"
VITE_API_HOST="http://localhost:8090/api"
DATABASE_URL="postgres://postgres:password@localhost:5432/trieve"
REDIS_URL="redis://:thisredispasswordisverysecureandcomplex@localhost:6379"
QDRANT_URL="http://localhost:6334"
S3_ENDPOINT="http://localhost:9000"
TIKA_URL="http://localhost:9998"
```

### Step 3: Start Services

```bash
# Start all services in detached mode
docker compose up -d

# Monitor logs (optional)
docker compose logs -f

# Check service status
docker compose ps
```

Expected services:
- `db` - PostgreSQL database (port 5432)
- `redis` - Redis cache (port 6379)
- `qdrant-database` - Vector database (ports 6333, 6334)
- `s3` - MinIO object storage (port 9000)
- `tika` - Document parser (port 9998)
- `keycloak` - Authentication (port 8080)
- `clickhouse-db` - Analytics database (port 8123)
- `server` - Main API server (port 8090)
- `ingestion-worker` - Chunk ingestion worker
- `file-worker` - File processing worker
- `delete-worker` - Deletion worker
- `dashboard` - Web UI (port 5173)
- `search` - Search UI (port 5174)
- `chat` - Chat UI (port 5175)

### Step 4: Wait for Services to Initialize

Services need time to start and initialize databases. This typically takes 5-10 minutes.

```bash
# Watch services become healthy
watch -n 5 'docker compose ps'

# Check specific service logs if stuck
docker compose logs keycloak
docker compose logs server
docker compose logs db
```

All services should show "Up" or "healthy" status.

## Organization and API Key Setup

### Access the Dashboard

1. Open browser to: **http://localhost:5173**
2. Click "Sign Up" or "Login"
3. Create an account (stored locally in Keycloak)

### Create an Organization

1. After login, you'll be prompted to create an organization
2. Enter organization name (e.g., "Test Organization")
3. Click "Create Organization"

### Get Your API Key

1. In the dashboard, go to **Settings** > **API Keys**
2. Click **"Create API Key"**
3. Name it (e.g., "cloud-pipeline-handler")
4. Set permissions: **Admin** or **Owner** (needed for dataset creation)
5. Copy the API key - you'll use this as `trieve_api_key` in your config

### Get Your Organization ID

1. In the dashboard, go to **Settings** > **Organization**
2. Copy the **Organization ID** (UUID format)
3. You'll use this as `trieve_organization_id` in your config

## Configuration for Your Use Case

### Multi-Tenant Device Isolation

Your use case requires:
- **One organization per customer** (or one shared organization for testing)
- **One dataset per device** within each organization
- **Dataset naming convention**: `org-{org_id}-device-{device_id}`

Example:
```
Organization ID: 123e4567-e89b-12d3-a456-426614174000

Datasets:
- org-123e4567-e89b-12d3-a456-426614174000-device-pump-001
- org-123e4567-e89b-12d3-a456-426614174000-device-compressor-002
- org-123e4567-e89b-12d3-a456-426614174000-device-hvac-003
```

### Dataset Configuration

When creating datasets via API, use these recommended settings:

```json
{
  "dataset_name": "org-{uuid}-device-{device_id}",
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

### File Upload Configuration

For PDF equipment manuals:

```json
{
  "base64_file": "<base64-encoded-pdf>",
  "file_name": "equipment-manual.pdf",
  "tag_set": ["device:pump-001", "manual", "maintenance"],
  "description": "Equipment maintenance manual for device pump-001",
  "target_splits_per_chunk": 20
}
```

## Health Checks and Verification

### 1. Check API Health

```bash
curl http://localhost:8090/api/health
```

Expected response: `200 OK`

### 2. Check API Documentation

Open in browser: **http://localhost:8090/redoc**

You should see the complete Trieve API documentation.

### 3. Check Dashboard

Open in browser: **http://localhost:5173**

You should see the Trieve dashboard login page.

### 4. Check Qdrant (Vector Database)

```bash
curl http://localhost:6333/health
```

Expected response: `{"status":"healthy"}`

### 5. Check MinIO (S3 Storage)

```bash
curl http://localhost:9000/minio/health/live
```

Expected response: `200 OK`

### 6. Test API with cURL

```bash
# Replace {YOUR_API_KEY} and {YOUR_ORG_ID}

# List datasets
curl -X GET "http://localhost:8090/api/dataset" \
  -H "Authorization: Bearer {YOUR_API_KEY}" \
  -H "TR-Organization: {YOUR_ORG_ID}"
```

## Troubleshooting

### Issue: Services won't start

**Check Docker resources:**
```bash
docker system df
docker system prune  # Free up space if needed
```

**Check port conflicts:**
```bash
# Check if ports are already in use
netstat -tlnp | grep -E '5173|5174|5175|6333|6379|8090|8080|5432'

# Or on macOS:
lsof -i :8090
```

**Solution**: Stop conflicting services or change ports in docker-compose.yml

### Issue: Keycloak won't start (authentication errors)

**Symptoms**: Server logs show OIDC errors

**Check Keycloak logs:**
```bash
docker compose logs keycloak | tail -50
```

**Solution**: Ensure `KC_PROXY="none"` in `.env` file, then restart:
```bash
docker compose restart keycloak
docker compose restart server
```

### Issue: Server shows "Database connection failed"

**Check database:**
```bash
docker compose logs db | tail -50
docker compose ps db
```

**Solution**: Wait for DB to fully initialize, or restart:
```bash
docker compose restart db
sleep 10
docker compose restart server
```

### Issue: "Could not decode base64 file" errors

**Cause**: Trieve expects base64url encoding (uses `-` and `_` instead of `+` and `/`)

**Solution**: Your Rust implementation should use standard base64 encoding. Trieve's server will handle both formats.

### Issue: File upload succeeds but chunks not created

**Check file-worker logs:**
```bash
docker compose logs file-worker | tail -100
```

**Check Tika (document parser):**
```bash
curl http://localhost:9998/version
```

**Solution**: Ensure Tika is running and healthy

### Issue: Search returns no results

**Possible causes:**
1. Chunks not yet ingested (check ingestion-worker logs)
2. Wrong dataset ID in query
3. Score threshold too high

**Check ingestion:**
```bash
docker compose logs ingestion-worker | tail -50
```

**Test with lower threshold:**
```json
{
  "query": "test",
  "score_threshold": 0.0,
  "page_size": 10
}
```

### Issue: High memory usage

**Check Docker stats:**
```bash
docker stats
```

**Solution**: Increase Docker memory limit in Docker Desktop settings, or reduce services:

```bash
# Stop non-essential services
docker compose stop chat search dashboard
```

### Issue: Cannot create organization in dashboard

**Symptoms**: Dashboard shows error when creating organization

**Check Keycloak and server connectivity:**
```bash
curl http://localhost:8080/health
curl http://localhost:8090/api/health
```

**Solution**: Ensure keycloak is fully started before using dashboard

## Resource Requirements

### Minimum Configuration
- 2 CPU cores
- 8GB RAM
- 10GB disk space
- Suitable for: Testing, single-user development

### Recommended Configuration
- 4+ CPU cores
- 16GB RAM
- 20GB+ disk space
- Suitable for: Multi-user development, realistic testing

### Production-Like Configuration
- 8+ CPU cores
- 32GB+ RAM
- 100GB+ SSD storage
- Suitable for: Load testing, staging environment

## Next Steps

After successful deployment:

1. **Create test datasets** - See [API_USAGE_GUIDE.md](./API_USAGE_GUIDE.md)
2. **Upload test PDFs** - Test with sample equipment manuals
3. **Run search queries** - Verify semantic search works
4. **Integrate with cloud-pipeline-handler** - Update your config.toml

## Configuration for cloud-pipeline-handler

Once Trieve is running, configure your Rust application:

```toml
[rag]
enabled = true
provider = "trieve"

# Use the values you obtained from the dashboard
trieve_api_endpoint = "http://localhost:8090/api"
trieve_api_key = "tr_YOUR_API_KEY_FROM_DASHBOARD"
trieve_organization_id = "YOUR_ORG_ID_FROM_DASHBOARD"

relevance_threshold = 0.25
max_results = 3
timeout_seconds = 30
```

## Stopping and Cleaning Up

```bash
# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes all data)
docker compose down -v

# Remove images as well
docker compose down -v --rmi all
```

## Advanced: Running Without Docker

For local development without Docker, see the main README.md section "Local development with Linux". This requires:
- Rust toolchain
- Node.js and Yarn
- PostgreSQL, Redis, and Qdrant installed locally
- Significantly more setup complexity

## Support and Resources

- **Trieve Documentation**: https://docs.trieve.ai
- **API Reference**: https://api.trieve.ai/redoc
- **Discord**: https://discord.gg/CuJVfgZf54
- **GitHub Issues**: https://github.com/devflowinc/trieve/issues
