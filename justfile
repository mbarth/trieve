# Trieve Rust Applications

# List available recipes
default:
    @just --list

# Start all services in parallel
dev:
    #!/usr/bin/env bash
    just server &
    just ingestion &
    just deletion &
    just file &
    just frontend &
    wait

# Start the main server with auto-reload
server:
    cd server && cargo watch -x run

# Start ingestion worker
ingestion:
    cd server && cargo run --bin ingestion-worker

# Start deletion worker  
deletion:
    cd server && cargo run --bin delete-worker

# Start file worker
file:
    cd server && cargo run --bin file-worker

# Start frontend development server
frontend:
    cd frontends/dashboard && yarn dev

# Start minimal Trieve with external PostgreSQL and Redis
minimal:
    docker compose -f docker-compose-minimal.yml up -d

# Stop minimal Trieve services
minimal-stop:
    docker compose -f docker-compose-minimal.yml down

# View minimal Trieve logs
minimal-logs:
    docker compose -f docker-compose-minimal.yml logs -f

# Test minimal Trieve setup
minimal-test:
    ./test-minimal-trieve.sh

# Stop all background processes (kill jobs started by 'just dev')
stop:
    #!/usr/bin/env bash
    pkill -f "cargo watch" 2>/dev/null || true
    pkill -f "target/debug/trieve-server" 2>/dev/null || true
    pkill -f "target/debug/ingestion-worker" 2>/dev/null || true  
    pkill -f "target/debug/delete-worker" 2>/dev/null || true
    pkill -f "target/debug/file-worker" 2>/dev/null || true
    pkill -f "cargo run --bin" 2>/dev/null || true
    pkill -f "turbo dev --filter=./frontends" 2>/dev/null || true
    pkill -f "trieve/frontends/.*/node_modules/.bin/vite" 2>/dev/null || true
    echo "Stopped all development processes"