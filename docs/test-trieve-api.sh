#!/bin/bash

# Trieve API Test Script for cloud-pipeline-handler Integration
# This script tests the Trieve API to verify it works correctly for your use case

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
API_ENDPOINT="${TRIEVE_API_ENDPOINT:-http://localhost:8090/api}"
API_KEY="${TRIEVE_API_KEY:-}"
ORG_ID="${TRIEVE_ORG_ID:-}"

# Test data
TEST_DEVICE_ID="pump-001"
TEST_DATASET_NAME="org-test-device-${TEST_DEVICE_ID}"
TEST_TRACKING_ID="device-${TEST_DEVICE_ID}"

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    echo "=== Checking Prerequisites ==="

    if [ -z "$API_KEY" ]; then
        print_error "TRIEVE_API_KEY not set!"
        echo "  Set it with: export TRIEVE_API_KEY='tr_your_api_key'"
        exit 1
    fi

    if [ -z "$ORG_ID" ]; then
        print_error "TRIEVE_ORG_ID not set!"
        echo "  Set it with: export TRIEVE_ORG_ID='your-org-uuid'"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        print_error "curl not found! Please install curl."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq not found! Please install jq."
        exit 1
    fi

    print_success "Prerequisites OK"
    echo ""
}

# Function to test API health
test_api_health() {
    echo "=== Testing API Health ==="

    RESPONSE=$(curl -s -w "\n%{http_code}" "$API_ENDPOINT/../health" || echo "000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" == "200" ]; then
        print_success "API is healthy (HTTP $HTTP_CODE)"
    else
        print_error "API health check failed (HTTP $HTTP_CODE)"
        exit 1
    fi
    echo ""
}

# Function to create dataset
create_dataset() {
    echo "=== Creating Test Dataset ==="

    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_ENDPOINT/dataset" \
        -H "Authorization: Bearer $API_KEY" \
        -H "TR-Organization: $ORG_ID" \
        -H "Content-Type: application/json" \
        -H "X-API-Version: v2" \
        -d @- << EOF
{
  "dataset_name": "$TEST_DATASET_NAME",
  "tracking_id": "$TEST_TRACKING_ID",
  "server_configuration": {
    "FULLTEXT_ENABLED": true,
    "SEMANTIC_ENABLED": true,
    "BM25_ENABLED": true,
    "EMBEDDING_SIZE": 1536,
    "DISTANCE_METRIC": "cosine"
  }
}
EOF
)

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    if [ "$HTTP_CODE" == "200" ]; then
        DATASET_ID=$(echo "$BODY" | jq -r '.id')
        print_success "Dataset created: $DATASET_ID"
        echo "  Name: $TEST_DATASET_NAME"
        echo "  Tracking ID: $TEST_TRACKING_ID"
    else
        print_error "Dataset creation failed (HTTP $HTTP_CODE)"
        echo "$BODY" | jq .
        exit 1
    fi
    echo ""
}

# Function to get dataset by tracking ID
get_dataset() {
    echo "=== Getting Dataset by Tracking ID ==="

    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$API_ENDPOINT/dataset/tracking_id/$TEST_TRACKING_ID" \
        -H "Authorization: Bearer $API_KEY" \
        -H "TR-Organization: $ORG_ID" \
        -H "X-API-Version: v2")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    if [ "$HTTP_CODE" == "200" ]; then
        DATASET_ID=$(echo "$BODY" | jq -r '.id')
        print_success "Dataset retrieved: $DATASET_ID"
    else
        print_error "Dataset retrieval failed (HTTP $HTTP_CODE)"
        echo "$BODY" | jq .
        exit 1
    fi
    echo ""
}

# Function to create a simple test PDF
create_test_pdf() {
    echo "=== Creating Test PDF ==="

    # Create a minimal PDF with test content
    cat > /tmp/test-manual.pdf << 'PDF_EOF'
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
/Resources <<
/Font <<
/F1 <<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
>>
>>
>>
>>
endobj
4 0 obj
<<
/Length 160
>>
stream
BT
/F1 12 Tf
50 700 Td
(Pump Maintenance Manual) Tj
0 -20 Td
(Model: XYZ-2000) Tj
0 -30 Td
(To maintain pump seals, follow these steps:) Tj
0 -15 Td
(1. Turn off pump and relieve pressure) Tj
0 -15 Td
(2. Remove seal housing) Tj
0 -15 Td
(3. Inspect seals for wear) Tj
0 -15 Td
(4. Replace damaged seals) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000317 00000 n
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
527
%%EOF
PDF_EOF

    TEST_PDF_BASE64=$(base64 -w 0 /tmp/test-manual.pdf)
    print_success "Test PDF created and encoded"
    echo ""
}

# Function to upload file
upload_file() {
    echo "=== Uploading Test PDF ==="

    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_ENDPOINT/file" \
        -H "Authorization: Bearer $API_KEY" \
        -H "TR-Dataset: $TEST_TRACKING_ID" \
        -H "Content-Type: application/json" \
        -H "X-API-Version: v2" \
        -d @- << EOF
{
  "base64_file": "$TEST_PDF_BASE64",
  "file_name": "pump-maintenance-manual.pdf",
  "tag_set": ["device:pump-001", "manual", "maintenance"],
  "description": "Test maintenance manual for pump-001",
  "metadata": {
    "device_id": "pump-001",
    "equipment_type": "pump",
    "test": true
  },
  "target_splits_per_chunk": 20
}
EOF
)

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    if [ "$HTTP_CODE" == "200" ]; then
        FILE_ID=$(echo "$BODY" | jq -r '.file_metadata.id')
        print_success "File uploaded: $FILE_ID"
        echo "  Filename: pump-maintenance-manual.pdf"
        print_info "Waiting 30 seconds for chunk processing..."
        sleep 30
    else
        print_error "File upload failed (HTTP $HTTP_CODE)"
        echo "$BODY" | jq .
        exit 1
    fi
    echo ""
}

# Function to search
search_chunks() {
    echo "=== Searching for Content ==="

    QUERY="$1"
    print_info "Query: \"$QUERY\""

    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_ENDPOINT/chunk/search" \
        -H "Authorization: Bearer $API_KEY" \
        -H "TR-Dataset: $TEST_TRACKING_ID" \
        -H "Content-Type: application/json" \
        -H "X-API-Version: v2" \
        -d @- << EOF
{
  "search_type": "hybrid",
  "query": "$QUERY",
  "page": 1,
  "page_size": 3,
  "score_threshold": 0.25,
  "filters": {
    "must": [
      {
        "field": "tag_set",
        "match_any": ["device:pump-001"]
      }
    ]
  }
}
EOF
)

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    if [ "$HTTP_CODE" == "200" ]; then
        RESULT_COUNT=$(echo "$BODY" | jq '.chunks | length')
        print_success "Search successful: $RESULT_COUNT results"

        if [ "$RESULT_COUNT" -gt 0 ]; then
            echo ""
            echo "Top Results:"
            echo "$BODY" | jq -r '.chunks[] | "  Score: \(.score)\n  Text: \(.chunk.chunk_html | .[0:100])...\n"'
        else
            print_info "No results found (chunks may still be processing)"
        fi
    else
        print_error "Search failed (HTTP $HTTP_CODE)"
        echo "$BODY" | jq .
        exit 1
    fi
    echo ""
}

# Function to cleanup
cleanup() {
    echo "=== Cleaning Up ==="

    print_info "Deleting test dataset..."

    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$API_ENDPOINT/dataset/$DATASET_ID" \
        -H "Authorization: Bearer $API_KEY" \
        -H "TR-Organization: $ORG_ID")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" == "204" ] || [ "$HTTP_CODE" == "200" ]; then
        print_success "Test dataset deleted"
    else
        print_error "Dataset deletion failed (HTTP $HTTP_CODE)"
    fi

    rm -f /tmp/test-manual.pdf
    echo ""
}

# Main execution
main() {
    echo "========================================"
    echo "Trieve API Integration Test"
    echo "========================================"
    echo ""

    check_prerequisites
    test_api_health
    create_dataset
    get_dataset
    create_test_pdf
    upload_file

    # Run multiple searches
    search_chunks "pump seals"
    search_chunks "maintenance"
    search_chunks "pressure"

    cleanup

    echo "========================================"
    print_success "All tests passed!"
    echo "========================================"
    echo ""
    echo "Your Trieve instance is working correctly for the cloud-pipeline-handler integration."
    echo ""
}

# Run main function
main
