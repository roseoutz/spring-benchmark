#!/usr/bin/env bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HEADER="${BLUE}======================================${NC}"
REPORT_DIR="reports/db-benchmark"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SERVICES=(
  vt-postgres
  vt-spring-vt
  vt-spring-platform
  vt-spring-webflux-java
  vt-spring-webflux-coroutine
)

mkdir -p "${REPORT_DIR}"

echo -e "$HEADER"
echo -e "${BLUE}   Benchmark Runner (services already up)${NC}"
echo -e "$HEADER"
echo ""

# Step 1: Verify containers are running and healthy
echo -e "${YELLOW}[1/4] Verifying Docker services...${NC}"
for service in "${SERVICES[@]}"; do
  if ! docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
    echo -e "${RED}✗ ${service} is not running${NC}"
    echo "Start the stack with docker compose up -d or scripts/full_benchmark.sh"
    exit 1
  fi

  STATUS=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$service")
  if [ "$STATUS" != "healthy" ] && [ "$STATUS" != "running" ]; then
    echo -e "${RED}✗ ${service} status: ${STATUS}${NC}"
    echo "Wait for services to become healthy before running tests."
    exit 1
  fi
  echo -e "${GREEN}✓ ${service} (${STATUS})${NC}"
done

echo -e "${GREEN}All services are ready${NC}"
echo ""

# Step 2: Warmup + benchmark (delegates to existing script)
echo -e "${YELLOW}[2/4] Running K6 warmup + benchmarks...${NC}"
./run_db_benchmark.sh

# Step 3: Generate report
echo -e "${YELLOW}[3/4] Generating comparison report...${NC}"
python3 scripts/generate_comparison_report.py "${REPORT_DIR}"

echo -e "${GREEN}Report generated at ${REPORT_DIR}${NC}"

# Step 4: Collect Docker stats
echo -e "${YELLOW}[4/4] Capturing Docker stats...${NC}"
DOCKER_STATS_FILE="${REPORT_DIR}/docker-stats-${TIMESTAMP}.txt"
docker stats --no-stream > "$DOCKER_STATS_FILE"

echo ""
echo -e "$HEADER"
echo -e "${GREEN}   Benchmark sequence completed${NC}"
echo -e "$HEADER"
echo ""
echo "Latest comparison report:"
echo "  ls -lt ${REPORT_DIR}/COMPARISON-*.md | head -1 | awk '{print \$NF}' | xargs cat"
echo ""
echo "Docker stats:"
echo "  cat ${DOCKER_STATS_FILE}"
