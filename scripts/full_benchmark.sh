#!/usr/bin/env bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}   Full Benchmark Automation${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check if containers are already running and healthy
echo -e "${YELLOW}Checking existing containers...${NC}"
HEALTHY_COUNT=$(docker compose ps --format json 2>/dev/null | jq -r 'select(.Health == "healthy") | .Name' | wc -l || echo "0")

if [ "$HEALTHY_COUNT" -ge 5 ]; then
    echo -e "${GREEN}✓ All containers are already running and healthy${NC}"
    echo -e "${GREEN}✓ Skipping build and startup, going directly to benchmarks${NC}"
    echo ""
    SKIP_STARTUP=true
else
    echo -e "${YELLOW}Containers not ready, starting from scratch...${NC}"
    echo ""
    SKIP_STARTUP=false
fi

if [ "$SKIP_STARTUP" = false ]; then
    # Step 1: Rebuild images to pick up source changes
    echo -e "${YELLOW}[1/7] Rebuilding Docker images...${NC}"
    docker compose build --pull --no-cache

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to rebuild Docker images${NC}"
        exit 1
    fi

    # Step 2: Docker Compose Up
    echo -e "${YELLOW}[2/7] Starting Docker containers...${NC}"
    docker compose up -d

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to start Docker containers${NC}"
        exit 1
    fi

    # Step 3: Health Check
    echo -e "${YELLOW}[3/7] Waiting for services to be healthy...${NC}"
    MAX_WAIT=120
    WAIT_TIME=0

    while [ $WAIT_TIME -lt $MAX_WAIT ]; do
        HEALTHY_COUNT=$(docker compose ps --format json 2>/dev/null | jq -r 'select(.Health == "healthy") | .Name' | wc -l || echo "0")
        TOTAL_COUNT=$(docker compose ps --format json 2>/dev/null | jq -r '.Name' | wc -l || echo "0")

        echo -ne "\rHealthy: ${HEALTHY_COUNT}/${TOTAL_COUNT} (${WAIT_TIME}s / ${MAX_WAIT}s)"

        # 모든 서비스가 healthy인지 확인
        if [ "$HEALTHY_COUNT" -ge 5 ]; then  # postgres + 4 Spring apps
            echo -e "\n${GREEN}✓ All services are healthy${NC}"
            break
        fi

        sleep 5
        WAIT_TIME=$((WAIT_TIME + 5))
    done

    if [ $WAIT_TIME -ge $MAX_WAIT ]; then
        echo -e "\n${RED}Error: Services did not become healthy in time${NC}"
        docker compose ps
        exit 1
    fi
fi

# Step 4: Warmup
echo -e "${YELLOW}[4/7] Warming up services (20 requests each)...${NC}"
PORTS=(8080 8081 8082 8083)
NAMES=("spring_vt" "spring_platform" "spring_webflux_java" "spring_webflux_coroutine")

for i in "${!PORTS[@]}"; do
    port=${PORTS[$i]}
    name=${NAMES[$i]}
    echo -n "  - ${name} (port ${port})... "

    # Simple warmup with curl (faster than k6)
    success_count=0
    for j in {1..20}; do
        if curl -s -f "http://localhost:${port}/api/orders?status=DELIVERED&daysAgo=30&page=0&size=10" > /dev/null 2>&1; then
            ((success_count++))
        fi
    done

    if [ $success_count -ge 15 ]; then
        echo -e "${GREEN}✓ (${success_count}/20 successful)${NC}"
    else
        echo -e "${RED}✗ (${success_count}/20 successful)${NC}"
    fi
done

echo -e "${GREEN}✓ Warmup completed${NC}"

# Step 5: Run Benchmarks
echo -e "${YELLOW}[5/7] Running K6 benchmarks...${NC}"
./scripts/run_db_benchmark.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Benchmark failed${NC}"
    exit 1
fi

# Step 6: Generate Report
echo -e "${YELLOW}[6/7] Generating comparison report...${NC}"
python3 scripts/generate_comparison_report.py reports/db-benchmark

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to generate report${NC}"
    exit 1
fi

# Step 7: Docker Stats
echo -e "${YELLOW}[7/7] Collecting Docker stats...${NC}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
docker stats --no-stream > "reports/db-benchmark/docker-stats-${TIMESTAMP}.txt"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Benchmark Completed Successfully${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Reports location: reports/db-benchmark/"
echo ""
echo "View latest comparison report:"
echo "  ls -lt reports/db-benchmark/COMPARISON-*.md | head -1 | awk '{print \$NF}' | xargs cat"
echo ""
echo "View Docker stats:"
echo "  cat reports/db-benchmark/docker-stats-${TIMESTAMP}.txt"
