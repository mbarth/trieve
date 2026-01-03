# Local Embedding Server Setup with Ollama

This guide explains how to configure Trieve to use a local embedding server instead of OpenAI's API to avoid rate limits.

## Prerequisites

- Ollama installed (already available at `/usr/local/bin/ollama`)
- Trieve running locally
- Access to Trieve API

## Step 1: Download and Run Embedding Model

```bash
# Pull the nomic embedding model (274MB)
ollama pull nomic-embed-text

# Start Ollama server in background
ollama serve &

# Test the embedding API
curl -X POST http://localhost:11434/api/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "nomic-embed-text", "prompt": "Hello world"}'
```

## Step 2: Configure Trieve Server Environment

Edit `/home/mbarth/dev/rustronaut/edge-ai-system/trieve/server/.env`:

```bash
# Point Trieve to local embedding server
EMBEDDING_SERVER_ORIGIN="http://localhost:11434"

# Keep sparse embedding servers disabled
SPARSE_SERVER_QUERY_ORIGIN=""
SPARSE_SERVER_DOC_ORIGIN=""

# Disable BM25 to avoid sparse embedding requirements
BM25_ACTIVE="false"
```

## Step 3: Update Dataset Configuration

### Option A: Automated Script (Recommended)

```bash
# Set your API key from cloud-pipeline-handler/config.toml
export TRIEVE_API_KEY="tr-IHtNIFjs5z1GHJB3e2RJoxIwIFCV5Mbo"

# Run the automated script to update all datasets
./scripts/update-all-orgs-to-local-embeddings.sh
```

The script will:
- Auto-detect your organization ID from `config.toml`
- List all datasets in the organization
- Ask for confirmation before updating
- Update all datasets to use local embeddings
- Provide a summary of results

### Option B: Manual Per-Organization

```bash
# Set environment variables
export TRIEVE_API_KEY="tr-IHtNIFjs5z1GHJB3e2RJoxIwIFCV5Mbo"
export TRIEVE_ORG_ID="9aa00c56-b5ff-4ffd-8421-49f301cb6190"

# Run script for specific organization
./scripts/update-all-datasets-to-local-embeddings.sh
```

### Option C: Manual API Calls

```bash
# Get your organization ID and API key from config.toml
ORG_ID="9aa00c56-b5ff-4ffd-8421-49f301cb6190"
API_KEY="tr-IHtNIFjs5z1GHJB3e2RJoxIwIFCV5Mbo"

# List datasets to find the correct dataset ID
curl -X GET "http://localhost:8090/api/dataset/organization/${ORG_ID}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "TR-Organization: ${ORG_ID}"

# Update dataset configuration (replace DATASET_ID with actual ID)
DATASET_ID="431b92c9-8995-48d3-85cd-572b4bf97a1f"

curl -X PUT "http://localhost:8090/api/dataset" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "TR-Organization: ${ORG_ID}" \
  -H "Content-Type: application/json" \
  -d '{
    "dataset_id": "'${DATASET_ID}'",
    "server_configuration": {
      "EMBEDDING_BASE_URL": "http://localhost:11434",
      "EMBEDDING_MODEL_NAME": "nomic-embed-text"
    }
  }'
```

## Step 4: Update Cloud Pipeline Handler

Edit `/home/mbarth/dev/rustronaut/edge-ai-system/cloud-pipeline-handler/src/rag/trieve.rs`:

Change search type from "hybrid" to "semantic" in both places:

```rust
// In query() function
search_type: "semantic".to_string(),

// In ask() function  
search_type: "semantic".to_string(),
```

## Step 5: Restart Services

```bash
# Restart Trieve services to apply configuration
cd /home/mbarth/dev/rustronaut/edge-ai-system/trieve
docker compose restart server ingestion-worker file-worker

# Restart your cloud pipeline handler
cd /home/mbarth/dev/rustronaut/edge-ai-system/cloud-pipeline-handler
cargo run
```

## Performance Expectations

- **Local embeddings**: 1-5 seconds per query (depending on hardware)
- **OpenAI API**: 200-500ms per query (when not rate limited)
- **Model size**: nomic-embed-text is 274MB
- **Embedding dimensions**: 768 (compatible with Trieve defaults)

## Troubleshooting

1. **"Connection refused" errors**: Ensure Ollama server is running (`ollama serve`)
2. **"Model not found"**: Ensure model is pulled (`ollama pull nomic-embed-text`)
3. **Still using OpenAI**: Check dataset configuration was updated successfully
4. **Slow performance**: Consider using GPU acceleration if available

## Alternative Models

You can try other embedding models:

```bash
# Smaller, faster model
ollama pull all-minilm

# Larger, potentially better quality
ollama pull mxbai-embed-large
```

Then update the dataset configuration with the new model name.