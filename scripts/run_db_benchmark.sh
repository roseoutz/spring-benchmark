#!/usr/bin/env bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ADAPTERS=("spring_vt" "spring_platform" "spring_webflux_java" "spring_webflux_coroutine")
REPORT_DIR="reports/db-benchmark"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_SCRIPT="k6/db-query.js"

# Create report directory
mkdir -p "${REPORT_DIR}"

echo -e "${GREEN}=== DB Benchmark Test ===${NC}"
echo "Timestamp: ${TIMESTAMP}"
echo "Report Directory: ${REPORT_DIR}"
echo ""

# Check if K6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}Error: K6 is not installed${NC}"
    echo "Install K6: https://k6.io/docs/getting-started/installation"
    exit 1
fi

# Check if Docker containers are running
echo -e "${YELLOW}Checking Docker containers...${NC}"
for adapter in "${ADAPTERS[@]}"; do
    container_name="vt-${adapter//_/-}"
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${RED}Error: Container ${container_name} is not running${NC}"
        echo "Run: docker-compose up -d"
        exit 1
    fi
done
echo -e "${GREEN}All containers are running${NC}"
echo ""

# Warmup
echo -e "${YELLOW}Warmup phase (100 requests per adapter)...${NC}"
for adapter in "${ADAPTERS[@]}"; do
    echo "Warming up ${adapter}..."
    # Ignore threshold failures during warmup (|| true)
    ADAPTER="${adapter}" k6 run \
        --vus 5 \
        --duration 20s \
        --quiet \
        "${TEST_SCRIPT}" > /dev/null 2>&1 || true
done
echo -e "${GREEN}Warmup completed${NC}"
echo ""

# Run benchmarks
for adapter in "${ADAPTERS[@]}"; do
    echo -e "${YELLOW}Testing ${adapter}...${NC}"

    RAW_JSON="${REPORT_DIR}/${adapter}-${TIMESTAMP}-raw.json"
    SUMMARY_JSON="${REPORT_DIR}/${adapter}-${TIMESTAMP}-summary.json"

    ADAPTER="${adapter}" k6 run \
        --out json="${RAW_JSON}" \
        "${TEST_SCRIPT}" | tee "${SUMMARY_JSON}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${adapter} completed${NC}"
    else
        echo -e "${RED}✗ ${adapter} failed${NC}"
    fi

    echo ""
    sleep 5  # Cooldown
done

echo -e "${GREEN}=== All tests completed ===${NC}"
echo "Results saved to: ${REPORT_DIR}"
echo ""
echo "Next steps:"
echo "1. Run: python3 scripts/generate_comparison_report.py ${REPORT_DIR}"
echo "2. View: cat reports/db-benchmark/COMPARISON-${TIMESTAMP}.md"
