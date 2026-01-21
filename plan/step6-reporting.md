# Step 6: 리포팅

## 목표
- Python으로 K6 JSON 결과 파싱 및 비교 리포트 생성
- Markdown 형식의 비교 테이블 생성
- 전체 벤치마크 프로세스 자동화 스크립트 작성
- Docker 사용법 문서 작성

## 작업 목록

### 6.1 Python 비교 리포트 생성 스크립트

#### 파일 생성
- [x] `/scripts/generate_comparison_report.py`

```python
#!/usr/bin/env python3

import json
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any

def parse_k6_summary(summary_path: Path) -> Dict[str, Any]:
    """K6 summary JSON 파싱"""
    with open(summary_path, 'r') as f:
        content = f.read()
        # K6 출력은 여러 JSON 객체를 포함할 수 있음, 마지막 것 사용
        lines = content.strip().split('\n')
        for line in reversed(lines):
            try:
                data = json.loads(line)
                if 'metrics' in data:
                    return data
            except json.JSONDecodeError:
                continue
    raise ValueError(f"No valid K6 summary found in {summary_path}")

def extract_metrics(data: Dict[str, Any]) -> Dict[str, float]:
    """주요 메트릭 추출"""
    metrics = data.get('metrics', {})

    http_req_duration = metrics.get('http_req_duration', {})
    http_reqs = metrics.get('http_reqs', {})
    http_req_failed = metrics.get('http_req_failed', {})

    return {
        'p50': http_req_duration.get('values', {}).get('p(50)', 0),
        'p95': http_req_duration.get('values', {}).get('p(95)', 0),
        'p99': http_req_duration.get('values', {}).get('p(99)', 0),
        'avg': http_req_duration.get('values', {}).get('avg', 0),
        'min': http_req_duration.get('values', {}).get('min', 0),
        'max': http_req_duration.get('values', {}).get('max', 0),
        'rps': http_reqs.get('values', {}).get('rate', 0),
        'total_requests': http_reqs.get('values', {}).get('count', 0),
        'error_rate': http_req_failed.get('values', {}).get('rate', 0) * 100,  # %
    }

def generate_comparison_table(results: Dict[str, Dict[str, float]]) -> str:
    """Markdown 비교 테이블 생성"""
    table = "| Adapter | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | RPS | Total Reqs | Error Rate |\n"
    table += "|---------|----------|----------|----------|----------|-----|------------|------------|\n"

    # P95 기준으로 정렬 (낮을수록 좋음)
    sorted_results = sorted(results.items(), key=lambda x: x[1]['p95'])

    for adapter, metrics in sorted_results:
        table += f"| {adapter:20} | {metrics['p50']:8.2f} | {metrics['p95']:8.2f} | {metrics['p99']:8.2f} | "
        table += f"{metrics['avg']:8.2f} | {metrics['rps']:7.2f} | {int(metrics['total_requests']):10} | "
        table += f"{metrics['error_rate']:6.2f}% |\n"

    return table

def generate_winner_analysis(results: Dict[str, Dict[str, float]]) -> str:
    """승자 분석"""
    analysis = "## 성능 분석\n\n"

    # P95 기준 최고 성능
    best_p95 = min(results.items(), key=lambda x: x[1]['p95'])
    analysis += f"### Latency Winner (P95 기준)\n"
    analysis += f"**{best_p95[0]}**: {best_p95[1]['p95']:.2f}ms\n\n"

    # RPS 기준 최고 성능
    best_rps = max(results.items(), key=lambda x: x[1]['rps'])
    analysis += f"### Throughput Winner (RPS 기준)\n"
    analysis += f"**{best_rps[0]}**: {best_rps[1]['rps']:.2f} req/s\n\n"

    # 에러율
    analysis += f"### Error Rates\n"
    for adapter, metrics in sorted(results.items()):
        analysis += f"- **{adapter}**: {metrics['error_rate']:.2f}%\n"

    analysis += "\n"

    return analysis

def generate_detailed_metrics(results: Dict[str, Dict[str, float]]) -> str:
    """상세 메트릭"""
    details = "## 상세 메트릭\n\n"

    for adapter, metrics in sorted(results.items()):
        details += f"### {adapter}\n\n"
        details += f"- **P50**: {metrics['p50']:.2f}ms\n"
        details += f"- **P95**: {metrics['p95']:.2f}ms\n"
        details += f"- **P99**: {metrics['p99']:.2f}ms\n"
        details += f"- **Average**: {metrics['avg']:.2f}ms\n"
        details += f"- **Min**: {metrics['min']:.2f}ms\n"
        details += f"- **Max**: {metrics['max']:.2f}ms\n"
        details += f"- **RPS**: {metrics['rps']:.2f} req/s\n"
        details += f"- **Total Requests**: {int(metrics['total_requests']):,}\n"
        details += f"- **Error Rate**: {metrics['error_rate']:.2f}%\n\n"

    return details

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_comparison_report.py <report_directory>")
        sys.exit(1)

    report_dir = Path(sys.argv[1])

    if not report_dir.exists():
        print(f"Error: Directory {report_dir} does not exist")
        sys.exit(1)

    # summary.json 파일 찾기
    summary_files = list(report_dir.glob("*-summary.json"))

    if not summary_files:
        print(f"Error: No summary JSON files found in {report_dir}")
        sys.exit(1)

    print(f"Found {len(summary_files)} summary files")

    # 각 어댑터별 결과 파싱
    results = {}
    for summary_file in summary_files:
        # 파일명에서 어댑터 이름 추출 (예: spring_vt-20240101_120000-summary.json)
        adapter_name = summary_file.stem.split('-')[0]

        try:
            data = parse_k6_summary(summary_file)
            metrics = extract_metrics(data)
            results[adapter_name] = metrics
            print(f"✓ Parsed {adapter_name}")
        except Exception as e:
            print(f"✗ Failed to parse {summary_file}: {e}")

    if not results:
        print("Error: No valid results parsed")
        sys.exit(1)

    # Markdown 리포트 생성
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = report_dir / f"COMPARISON-{timestamp}.md"

    with open(output_file, 'w') as f:
        f.write(f"# DB Performance Comparison Report\n\n")
        f.write(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"**Test Scenario**: 10M Orders JOIN Query (1 CPU, 1GB RAM per service)\n\n")

        f.write("---\n\n")
        f.write("## 비교 테이블\n\n")
        f.write(generate_comparison_table(results))
        f.write("\n")

        f.write("---\n\n")
        f.write(generate_winner_analysis(results))

        f.write("---\n\n")
        f.write(generate_detailed_metrics(results))

        f.write("---\n\n")
        f.write("## 테스트 환경\n\n")
        f.write("- **PostgreSQL**: 2 CPU, 2GB RAM\n")
        f.write("- **Spring Apps**: 1 CPU, 1GB RAM (각각)\n")
        f.write("- **Data**: 10M orders, 1M customers, 10K products\n")
        f.write("- **Query**: 3-way JOIN with status filter and pagination\n")
        f.write("- **K6 Load**: 20 VUs, 2 minutes steady state\n")

    print(f"\n✓ Report generated: {output_file}")
    print(f"\nView report:")
    print(f"  cat {output_file}")

if __name__ == "__main__":
    main()
```

#### 실행 권한 부여
```bash
chmod +x /Users/turner/Desktop/git/vt/scripts/generate_comparison_report.py
```

### 6.2 전체 벤치마크 통합 스크립트

#### 파일 생성
- [x] `/scripts/full_benchmark.sh`

```bash
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

# Step 1: Docker Compose Up
echo -e "${YELLOW}[1/6] Starting Docker containers...${NC}"
docker-compose up -d

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start Docker containers${NC}"
    exit 1
fi

# Step 2: Health Check
echo -e "${YELLOW}[2/6] Waiting for services to be healthy...${NC}"
MAX_WAIT=120
WAIT_TIME=0

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    HEALTHY_COUNT=$(docker-compose ps --format json | jq -r '.Health' | grep -c "healthy" || true)
    TOTAL_COUNT=$(docker-compose ps --format json | jq -r '.Name' | wc -l)

    echo -ne "\rHealthy: ${HEALTHY_COUNT}/${TOTAL_COUNT} (${WAIT_TIME}s / ${MAX_WAIT}s)"

    if [ "$HEALTHY_COUNT" -eq "$TOTAL_COUNT" ]; then
        echo -e "\n${GREEN}✓ All services are healthy${NC}"
        break
    fi

    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo -e "\n${RED}Error: Services did not become healthy in time${NC}"
    docker-compose ps
    exit 1
fi

# Step 3: Warmup
echo -e "${YELLOW}[3/6] Warming up services (100 requests each)...${NC}"
ADAPTERS=("spring_vt" "spring_platform" "spring_webflux_java" "spring_webflux_coroutine")

for adapter in "${ADAPTERS[@]}"; do
    echo -n "  - ${adapter}... "
    ADAPTER="${adapter}" k6 run --vus 5 --duration 20s --quiet k6/db-query.js > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
done

echo -e "${GREEN}✓ Warmup completed${NC}"

# Step 4: Run Benchmarks
echo -e "${YELLOW}[4/6] Running K6 benchmarks...${NC}"
./scripts/run_db_benchmark.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Benchmark failed${NC}"
    exit 1
fi

# Step 5: Generate Report
echo -e "${YELLOW}[5/6] Generating comparison report...${NC}"
python3 scripts/generate_comparison_report.py reports/db-benchmark

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to generate report${NC}"
    exit 1
fi

# Step 6: Docker Stats
echo -e "${YELLOW}[6/6] Collecting Docker stats...${NC}"
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
echo "  cat reports/db-benchmark/COMPARISON-*.md | tail -n +1"
echo ""
echo "View Docker stats:"
echo "  cat reports/db-benchmark/docker-stats-${TIMESTAMP}.txt"
```

#### 실행 권한 부여
```bash
chmod +x /Users/turner/Desktop/git/vt/scripts/full_benchmark.sh
```

### 6.3 Docker 사용법 문서

#### 파일 생성
- [x] `/docker/README.md`

```markdown
# Docker Setup Guide

Spring Boot Virtual Threads 성능 비교를 위한 Docker 환경 설정 가이드입니다.

## 사전 준비

### Docker Desktop 설치
- macOS/Windows: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Linux: [Docker Engine](https://docs.docker.com/engine/install/)

### 리소스 할당
Docker Desktop > Settings > Resources:
- **CPU**: 최소 4 cores (권장 8 cores)
- **Memory**: 최소 6GB (권장 8GB)
- **Swap**: 2GB
- **Disk**: 20GB 이상

## 빠른 시작

### 1. 전체 빌드 및 실행
```bash
docker-compose up -d
```

### 2. 로그 확인
```bash
docker-compose logs -f
```

### 3. 상태 확인
```bash
docker-compose ps
```

### 4. 종료
```bash
docker-compose down
```

## 개별 서비스 관리

### PostgreSQL만 실행
```bash
docker-compose up postgres -d
```

### 특정 Spring 앱 실행
```bash
docker-compose up spring_vt -d
docker-compose up spring_platform -d
docker-compose up spring_webflux_java -d
docker-compose up spring_webflux_coroutine -d
```

### 서비스 재시작
```bash
docker-compose restart spring_vt
```

### 로그 확인 (특정 서비스)
```bash
docker-compose logs -f postgres
docker-compose logs -f spring_vt
```

## 데이터베이스 관리

### PostgreSQL 접속
```bash
docker exec -it vt-postgres psql -U vt_user -d vt_benchmark
```

### 데이터 확인
```sql
\dt                          -- 테이블 목록
SELECT COUNT(*) FROM orders; -- 10000000
SELECT COUNT(*) FROM customers; -- 1000000
SELECT COUNT(*) FROM products; -- 10000
\q                          -- 종료
```

### 데이터 초기화 (재생성)
```bash
docker-compose down -v  # Volume 삭제
docker-compose up postgres -d
```

초기 데이터 생성에 **3-5분** 소요됩니다.

## 리소스 모니터링

### 실시간 모니터링
```bash
docker stats
```

### 스냅샷 확인
```bash
docker stats --no-stream
```

### 개별 컨테이너 확인
```bash
docker stats vt-spring-vt --no-stream
```

## 트러블슈팅

### 빌드 실패
```bash
# 캐시 없이 재빌드
docker-compose build --no-cache

# 특정 서비스만 재빌드
docker-compose build --no-cache spring_vt
```

### 메모리 부족 (OOMKilled)
```bash
# 컨테이너 상태 확인
docker-compose ps

# 로그에서 OOMKilled 확인
docker-compose logs spring_vt | grep -i oom
```

**해결 방법**:
1. Docker Desktop 메모리 증가
2. `docker-compose.yml`의 메모리 제한 조정
3. `spring-base.Dockerfile`의 JVM `-Xmx` 값 조정

### Port 충돌
```bash
# 포트 사용 확인
lsof -i :8080
lsof -i :8081
lsof -i :8082
lsof -i :8083
lsof -i :5432

# 충돌 시 해당 프로세스 종료 또는 docker-compose.yml 포트 변경
```

### Health Check 실패
```bash
# Health check 상태 확인
docker inspect vt-spring-vt | jq '.[0].State.Health'

# 컨테이너 내부 확인
docker exec -it vt-spring-vt sh
wget --spider http://localhost:8080/actuator/health
```

### 네트워크 문제
```bash
# 네트워크 확인
docker network ls
docker network inspect vt_vt-network

# 네트워크 재생성
docker-compose down
docker network prune
docker-compose up -d
```

## 디스크 정리

### 사용하지 않는 리소스 정리
```bash
docker system prune -a
```

### Volume 정리
```bash
docker volume prune
```

### 특정 Volume 삭제
```bash
docker volume rm vt_postgres_data
```

## 환경 변수 오버라이드

### .env 파일 생성
```bash
# .env
SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/vt_benchmark
SPRING_DATASOURCE_USERNAME=vt_user
SPRING_DATASOURCE_PASSWORD=custom_password

POSTGRES_PASSWORD=custom_password
```

### 실행 시 환경 변수 전달
```bash
POSTGRES_PASSWORD=custom docker-compose up -d
```

## 성능 최적화 Tips

### 1. BuildKit 활성화
```bash
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
docker-compose build
```

### 2. 병렬 빌드
```bash
docker-compose build --parallel
```

### 3. 이미지 레이어 캐싱
Dockerfile의 COPY 순서 최적화 (자주 변경되는 파일은 나중에)

## 참고 자료

- [Docker Compose CLI Reference](https://docs.docker.com/compose/reference/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
```

## 검증 방법

### Python 스크립트 테스트
```bash
# 의존성 확인 (Python 3.8+)
python3 --version

# 스크립트 실행 테스트
python3 scripts/generate_comparison_report.py reports/db-benchmark
```

### 전체 벤치마크 실행
```bash
./scripts/full_benchmark.sh
```

### 리포트 확인
```bash
ls -lh reports/db-benchmark/
cat reports/db-benchmark/COMPARISON-*.md
```

### 문서 검토
```bash
cat docker/README.md
cat k6/README.md
```

## 예상 소요 시간
1일 (8시간)
- Python 리포트 스크립트: 3시간
- 통합 벤치마크 스크립트: 2시간
- 문서 작성: 2시간
- 최종 검증: 1시간

## 완료 후 다음 작업
- CLAUDE.md 업데이트
- 전체 시스템 통합 테스트
- 실제 벤치마크 실행 및 결과 분석
