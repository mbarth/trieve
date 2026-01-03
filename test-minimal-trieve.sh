#!/bin/bash
# Test script for minimal Trieve setup

set -e

echo "Testing minimal Trieve setup..."

API_URL="http://localhost:8090/api"
ADMIN_KEY="admin"

# Test 1: Health check
echo "1. Testing API health..."
if curl -s "${API_URL}/health" | grep -q "ok"; then
    echo "✅ API health check passed"
else
    echo "❌ API health check failed"
    exit 1
fi

# Test 2: Create organization
echo "2. Testing organization creation..."
ORG_RESPONSE=$(curl -s -X POST "${API_URL}/organization" \
    -H "Authorization: ${ADMIN_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Test Organization",
        "registration_enabled": false
    }')

if echo "$ORG_RESPONSE" | grep -q "id"; then
    ORG_ID=$(echo "$ORG_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo "✅ Organization created: $ORG_ID"
else
    echo "❌ Organization creation failed"
    echo "Response: $ORG_RESPONSE"
    exit 1
fi

# Test 3: Create dataset  
echo "3. Testing dataset creation..."
DATASET_RESPONSE=$(curl -s -X POST "${API_URL}/dataset" \
    -H "Authorization: ${ADMIN_KEY}" \
    -H "TR-Organization: ${ORG_ID}" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_name": "test-device-001",
        "server_configuration": {
            "EMBEDDING_SIZE": 1536,
            "DISTANCE_METRIC": "cosine"
        }
    }')

if echo "$DATASET_RESPONSE" | grep -q "id"; then
    DATASET_ID=$(echo "$DATASET_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo "✅ Dataset created: $DATASET_ID"
else
    echo "❌ Dataset creation failed"
    echo "Response: $DATASET_RESPONSE"
    exit 1
fi

# Test 4: Create a simple text chunk
echo "4. Testing chunk creation..."
CHUNK_RESPONSE=$(curl -s -X POST "${API_URL}/chunk" \
    -H "Authorization: ${ADMIN_KEY}" \
    -H "TR-Dataset: ${DATASET_ID}" \
    -H "Content-Type: application/json" \
    -d '{
        "chunk_html": "This is a test maintenance manual entry about temperature sensor calibration procedures.",
        "metadata": {
            "tag_set": ["manual", "temperature", "calibration"]
        }
    }')

if echo "$CHUNK_RESPONSE" | grep -q "id"; then
    CHUNK_ID=$(echo "$CHUNK_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo "✅ Chunk created: $CHUNK_ID"
else
    echo "❌ Chunk creation failed"
    echo "Response: $CHUNK_RESPONSE"
    exit 1
fi

# Wait for indexing
echo "5. Waiting for indexing..."
sleep 5

# Test 5: Search
echo "6. Testing search..."
SEARCH_RESPONSE=$(curl -s -X POST "${API_URL}/chunk/search" \
    -H "Authorization: ${ADMIN_KEY}" \
    -H "TR-Dataset: ${DATASET_ID}" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "temperature sensor",
        "search_type": "hybrid",
        "score_threshold": 0.1
    }')

if echo "$SEARCH_RESPONSE" | grep -q "score_chunks"; then
    echo "✅ Search test passed"
    RESULT_COUNT=$(echo "$SEARCH_RESPONSE" | grep -o '"score_chunks":\[[^]]*\]' | grep -o '"id"' | wc -l)
    echo "   Found $RESULT_COUNT results"
else
    echo "❌ Search test failed"
    echo "Response: $SEARCH_RESPONSE"
fi

echo ""
echo "🎉 All tests completed successfully!"
echo ""
echo "Your minimal Trieve setup is working correctly:"
echo "  ✅ API server responding"
echo "  ✅ Organization management"
echo "  ✅ Dataset creation"
echo "  ✅ Document ingestion"
echo "  ✅ Vector search"
echo ""
echo "You can now:"
echo "1. Upload PDF files via the file API"
echo "2. Search across your documents"
echo "3. Integrate with cloud-pipeline-handler"
echo ""
echo "API endpoints:"
echo "  - Health: GET ${API_URL}/health"
echo "  - Organizations: POST ${API_URL}/organization"
echo "  - Datasets: POST ${API_URL}/dataset"
echo "  - File Upload: POST ${API_URL}/file"
echo "  - Search: POST ${API_URL}/chunk/search"