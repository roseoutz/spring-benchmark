# K6 Performance Testing

K6를 사용한 Spring Boot 애플리케이션 성능 테스트입니다.

## 사전 준비

### K6 설치

**macOS**:
```bash
brew install k6
```

**Linux (Debian/Ubuntu)**:
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

**파라미터**:
- `status`: 주문 상태 (기본: DELIVERED)
- `daysAgo`: 조회 기간 (기본: 30일)
- `page`: 페이지 번호 (랜덤 0-9)
- `size`: 페이지 크기 (100)

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
ls -lt reports/db-benchmark/COMPARISON-*.md | head -1 | awk '{print $NF}' | xargs cat
```

### 완전 자동화

```bash
./scripts/full_benchmark.sh
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
- `cpu_workload_duration`: CPU 워크로드 메트릭

### 통계
- `p(50)`: 50th percentile (중앙값)
- `p(95)`: 95th percentile
- `p(99)`: 99th percentile
- `avg`: 평균
- `min/max`: 최소/최대

## 어댑터 선택

환경 변수 `ADAPTER`로 테스트할 어댑터를 선택합니다:

```bash
ADAPTER=spring_vt k6 run k6/db-query.js
ADAPTER=spring_platform k6 run k6/db-query.js
ADAPTER=spring_webflux_java k6 run k6/db-query.js
ADAPTER=spring_webflux_coroutine k6 run k6/db-query.js
```

## 테스트 커스터마이징

### VU 수 변경

```bash
k6 run --vus 50 --duration 5m k6/db-query.js
```

### 다른 시나리오 패턴

```javascript
export const options = {
  stages: [
    { duration: '2m', target: 100 },  // 빠른 ramp-up
    { duration: '5m', target: 100 },  // 5분 유지
    { duration: '2m', target: 200 },  // 부하 증가
    { duration: '5m', target: 200 },  // 5분 유지
    { duration: '2m', target: 0 },    // ramp-down
  ],
};
```

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

```bash
docker exec -it vt-postgres psql -U vt_user -d vt_benchmark -c "SELECT COUNT(*) FROM orders;"
```

### 테스트 재실행

```bash
# 컨테이너 재시작
docker-compose restart

# Health check 대기
sleep 30

# 테스트 재실행
./scripts/run_db_benchmark.sh
```

## 결과 해석

### 좋은 결과
- P95 < 1000ms
- P99 < 2000ms
- Error rate < 0.1%
- RPS > 30

### 나쁜 결과
- P95 > 3000ms
- P99 > 5000ms
- Error rate > 1%
- 많은 timeout 에러

## 성능 개선 팁

### 애플리케이션 레벨
1. Connection pool 크기 조정
2. JVM 메모리 설정 최적화
3. 쿼리 최적화 (인덱스 확인)

### 인프라 레벨
1. Docker 리소스 제한 완화 (테스트용)
2. PostgreSQL 튜닝 파라미터 조정
3. 네트워크 대역폭 확인

## 참고 자료

- [K6 공식 문서](https://k6.io/docs/)
- [K6 Thresholds](https://k6.io/docs/using-k6/thresholds/)
- [K6 Metrics](https://k6.io/docs/using-k6/metrics/)
- [K6 Executors](https://k6.io/docs/using-k6/scenarios/executors/)
