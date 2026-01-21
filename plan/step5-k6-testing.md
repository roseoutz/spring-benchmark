# Step 5: K6 테스트

## 목표
- K6 DB 조회 시나리오 작성 (db-query.js)
- K6 Mixed Workload 시나리오 작성 (mixed-workload.js)
- 벤치마크 자동화 스크립트 작성 (run_db_benchmark.sh)
- 각 어댑터별 성능 측정 및 JSON 결과 저장

## 작업 목록

### 5.1 K6 DB 조회 시나리오

#### 파일 생성
- [x] `/k6/db-query.js`

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';

// Custom metrics
const dbQueryDuration = new Trend('db_query_duration', true);
const dbQueryErrors = new Counter('db_query_errors');

// Adapter 포트 매핑
const adapterTargets = {
  'spring_vt': 'http://localhost:8080',
  'spring_platform': 'http://localhost:8081',
  'spring_webflux_java': 'http://localhost:8082',
  'spring_webflux_coroutine': 'http://localhost:8083',
};

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp-up to 20 VUs
    { duration: '2m', target: 20 },   // Stay at 20 VUs for 2 minutes
    { duration: '30s', target: 0 },   // Ramp-down to 0
  ],
  thresholds: {
    'http_req_duration': ['p(95)<2000', 'p(99)<3000'],  // 95% < 2s, 99% < 3s
    'http_req_failed': ['rate<0.01'],                    // Error rate < 1%
    'db_query_duration': ['p(95)<2000'],
  },
};

export default function () {
  // Get adapter from environment variable
  const adapterKey = (__ENV.ADAPTER || 'spring_vt').toLowerCase();
  const baseUrl = adapterTargets[adapterKey];

  if (!baseUrl) {
    throw new Error(`Unknown adapter: ${adapterKey}`);
  }

  // Random parameters
  const page = Math.floor(Math.random() * 10);  // 0-9
  const size = 100;
  const daysAgo = 30;
  const status = 'DELIVERED';

  const url = `${baseUrl}/api/orders?status=${status}&daysAgo=${daysAgo}&page=${page}&size=${size}`;

  const params = {
    headers: {
      'Accept': 'application/json',
    },
    timeout: '10s',
  };

  const res = http.get(url, params);

  // Record custom metric
  dbQueryDuration.add(res.timings.duration);

  // Validation
  const checkResult = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has content': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.content && Array.isArray(body.content);
      } catch (e) {
        return false;
      }
    },
    'response time < 3s': (r) => r.timings.duration < 3000,
  });

  if (!checkResult) {
    dbQueryErrors.add(1);
  }

  // Think time
  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
```

### 5.2 K6 Mixed Workload 시나리오

#### 파일 생성
- [x] `/k6/mixed-workload.js`

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

// Custom metrics
const dbQueryDuration = new Trend('db_query_duration', true);
const cpuWorkloadDuration = new Trend('cpu_workload_duration', true);

// Adapter 포트 매핑
const adapterTargets = {
  'spring_vt': 'http://localhost:8080',
  'spring_platform': 'http://localhost:8081',
  'spring_webflux_java': 'http://localhost:8082',
  'spring_webflux_coroutine': 'http://localhost:8083',
};

// Test configuration
export const options = {
  scenarios: {
    db_queries: {
      executor: 'constant-vus',
      exec: 'dbQueryScenario',
      vus: 15,
      duration: '3m',
    },
    cpu_workload: {
      executor: 'constant-vus',
      exec: 'cpuWorkloadScenario',
      vus: 5,
      duration: '3m',
    },
  },
  thresholds: {
    'http_req_duration': ['p(95)<2500'],
    'http_req_failed': ['rate<0.01'],
  },
};

export function dbQueryScenario() {
  const adapterKey = (__ENV.ADAPTER || 'spring_vt').toLowerCase();
  const baseUrl = adapterTargets[adapterKey];

  const page = Math.floor(Math.random() * 10);
  const url = `${baseUrl}/api/orders?status=DELIVERED&daysAgo=30&page=${page}&size=100`;

  const res = http.get(url);
  dbQueryDuration.add(res.timings.duration);

  check(res, {
    'db query status 200': (r) => r.status === 200,
  });

  sleep(1);
}

export function cpuWorkloadScenario() {
  const adapterKey = (__ENV.ADAPTER || 'spring_vt').toLowerCase();
  const baseUrl = adapterTargets[adapterKey];

  const tasks = Math.floor(Math.random() * 20) + 10;  // 10-30
  const workMs = Math.floor(Math.random() * 30) + 20; // 20-50

  const url = `${baseUrl}/api/workload?tasks=${tasks}&workMs=${workMs}`;

  const res = http.get(url);
  cpuWorkloadDuration.add(res.timings.duration);

  check(res, {
    'cpu workload status 200': (r) => r.status === 200,
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
```

### 5.3 벤치마크 실행 스크립트

#### 파일 생성
- [x] `/scripts/run_db_benchmark.sh`

```bash
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
    ADAPTER="${adapter}" k6 run \
        --vus 5 \
        --duration 20s \
        --quiet \
        "${TEST_SCRIPT}" > /dev/null 2>&1
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
```

#### 실행 권한 부여
```bash
chmod +x /Users/turner/Desktop/git/vt/scripts/run_db_benchmark.sh
```

### 5.4 K6 README 작성

#### 파일 생성
- [x] `/k6/README.md`

```markdown
# K6 Performance Testing

K6를 사용한 Spring Boot 애플리케이션 성능 테스트입니다.

## 사전 준비

### K6 설치

**macOS**:
```bash
brew install k6
```

**Linux**:
```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

**Windows**:
```powershell
choco install k6
```

## 테스트 시나리오

### 1. DB 조회 테스트 (db-query.js)

1000만건 데이터 조인 조회 성능 테스트

**실행 방법**:
```bash
# 특정 어댑터 테스트
ADAPTER=spring_vt k6 run k6/db-query.js

# 모든 어댑터 자동 테스트
./scripts/run_db_benchmark.sh
```

**테스트 설정**:
- Ramp-up: 30초 (0 → 20 VU)
- Steady: 2분 (20 VU 유지)
- Ramp-down: 30초 (20 → 0 VU)
- 총 소요 시간: 3분

**Thresholds**:
- P95 < 2초
- P99 < 3초
- Error rate < 1%

### 2. Mixed Workload 테스트 (mixed-workload.js)

DB 조회 + CPU 워크로드 혼합 테스트

**실행 방법**:
```bash
ADAPTER=spring_vt k6 run k6/mixed-workload.js
```

**테스트 설정**:
- DB 조회: 15 VU (3분 동안)
- CPU 워크로드: 5 VU (3분 동안)
- 총 소요 시간: 3분

## 결과 분석

### 수동 실행 (단일 어댑터)

```bash
ADAPTER=spring_vt k6 run --out json=results.json k6/db-query.js
```

### 자동 실행 (모든 어댑터)

```bash
# 1. 벤치마크 실행
./scripts/run_db_benchmark.sh

# 2. 비교 리포트 생성
python3 scripts/generate_comparison_report.py reports/db-benchmark

# 3. 결과 확인
cat reports/db-benchmark/COMPARISON-*.md
```

## 주요 메트릭

### HTTP 메트릭
- `http_req_duration`: 전체 요청 시간
- `http_req_waiting`: 서버 응답 대기 시간 (TTFB)
- `http_req_connecting`: TCP 연결 시간
- `http_req_failed`: 실패한 요청 비율

### Custom 메트릭
- `db_query_duration`: DB 조회 전용 메트릭
- `db_query_errors`: DB 조회 에러 카운트

### 통계
- `p(50)`: 50th percentile (중앙값)
- `p(95)`: 95th percentile
- `p(99)`: 99th percentile
- `avg`: 평균
- `min/max`: 최소/최대

## 트러블슈팅

### K6 설치 확인
```bash
k6 version
```

### Docker 컨테이너 상태 확인
```bash
docker-compose ps
```

### 테스트 중 에러 발생 시
1. `docker-compose logs -f [service_name]`로 로그 확인
2. `docker stats`로 리소스 사용량 확인
3. PostgreSQL 연결 상태 확인

### 테스트 재실행
```bash
# 컨테이너 재시작
docker-compose restart

# Health check 대기
sleep 30

# 테스트 재실행
./scripts/run_db_benchmark.sh
```

## 참고 자료

- [K6 공식 문서](https://k6.io/docs/)
- [K6 Thresholds](https://k6.io/docs/using-k6/thresholds/)
- [K6 Metrics](https://k6.io/docs/using-k6/metrics/)
```

## 검증 방법

### K6 설치 확인
```bash
k6 version
```

### K6 스크립트 문법 검증
```bash
k6 inspect k6/db-query.js
k6 inspect k6/mixed-workload.js
```

### 단일 어댑터 테스트
```bash
# Docker 실행
docker-compose up -d

# Health check 대기
sleep 30

# K6 테스트
ADAPTER=spring_vt k6 run k6/db-query.js
```

### 전체 벤치마크 실행
```bash
./scripts/run_db_benchmark.sh
```

### 결과 파일 확인
```bash
ls -lh reports/db-benchmark/
cat reports/db-benchmark/spring_vt-*-summary.json | jq '.metrics.http_req_duration'
```

## 예상 소요 시간
1일 (8시간)
- K6 스크립트 작성: 3시간
- 벤치마크 스크립트 작성: 2시간
- 테스트 실행 및 검증: 3시간

## 다음 단계
Step 6: 리포팅 (Python 비교 리포트 생성)
