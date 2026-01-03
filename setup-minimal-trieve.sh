#!/bin/bash
# Setup script for minimal Trieve with existing PostgreSQL and Redis

set -e

echo "Setting up minimal Trieve with existing PostgreSQL and Redis..."

# Check if PostgreSQL is running locally
if ! pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
    echo "ERROR: PostgreSQL is not running on localhost:5432"
    echo "Please start PostgreSQL first"
    exit 1
fi

# Check if Redis is running locally
if ! redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; then
    echo "ERROR: Redis is not running on localhost:6379"
    echo "Please start Redis first"
    exit 1
fi

echo "✅ PostgreSQL and Redis are running"

# Create separate Trieve database
echo "Creating Trieve database..."
psql -h localhost -p 5432 -U mbarth -d postgres -c "
CREATE DATABASE trieve_db;
" 2>/dev/null || echo "Database trieve_db already exists"

echo "✅ Trieve database created"

# Copy minimal environment configuration
if [ ! -f .env ]; then
    echo "Copying minimal environment configuration..."
    cp .env.minimal .env
    echo "✅ Environment configuration copied to .env"
    echo "📝 Please edit .env and adjust database URLs if needed"
else
    echo "⚠️  .env already exists, not overwriting"
    echo "📝 Consider backing up your .env and copying from .env.minimal"
fi

# Build and start minimal services
echo "Building and starting minimal Trieve services..."
echo "This will start: qdrant, s3 (minio), tika, server, ingestion-worker, file-worker"

docker compose -f docker-compose-minimal.yml up -d --build

echo "🔄 Waiting for services to start..."
sleep 30

# Check service health
echo "Checking service health..."

# Check Qdrant
if curl -s http://localhost:6333/health >/dev/null; then
    echo "✅ Qdrant is healthy"
else
    echo "❌ Qdrant is not responding"
fi

# Check MinIO
if curl -s http://localhost:9000/minio/health/live >/dev/null; then
    echo "✅ MinIO (S3) is healthy"
else
    echo "❌ MinIO is not responding"
fi

# Check Tika
if curl -s http://localhost:9998/version >/dev/null; then
    echo "✅ Tika is healthy"
else
    echo "❌ Tika is not responding"
fi

# Check Trieve server
if curl -s http://localhost:8090/api/health >/dev/null; then
    echo "✅ Trieve server is healthy"
else
    echo "❌ Trieve server is not responding"
fi

echo ""
echo "🎉 Minimal Trieve setup complete!"
echo ""
echo "Services running:"
echo "  - Trieve API: http://localhost:8090"
echo "  - Qdrant (vectors): http://localhost:6333"
echo "  - MinIO (files): http://localhost:9000"
echo "  - Tika (PDF): http://localhost:9998"
echo ""
echo "Database connections:"
echo "  - PostgreSQL: localhost:5432/trieve_db"
echo "  - Redis: localhost:6379"
echo ""
echo "Next steps:"
echo "1. Test the API: curl http://localhost:8090/api/health"
echo "2. Create an organization and dataset via API"
echo "3. Upload documents and test search"
echo ""
echo "To stop services: docker compose -f docker-compose-minimal.yml down"
echo "To view logs: docker compose -f docker-compose-minimal.yml logs -f"