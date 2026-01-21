# Spring Boot Virtual Threads DB Performance Test - Implementation Plan

## 개요

이 프로젝트는 Spring Boot 4 / Java 24 환경에서 Virtual Threads, Platform Threads, WebFlux (Java), WebFlux (Kotlin Coroutines)의 성능을 PostgreSQL 1000만건 JOIN 조회로 비교합니다.

## 목표

- **환경**: Docker 1 CPU 1GB 메모리 제한
- **데이터**: PostgreSQL 1000만건 orders + 100만건 customers + 1만건 products
- **테스트**: K6 부하 테스트 (20 VUs, 2분)
- **결과**: Markdown 비교 리포트 자동 생성

## 프로젝트 구조

```
vt/
├── business/              # 순수 비즈니스 로직 (공통)
├── data-jpa/             # JPA + JDBC (NEW)
├── data-r2dbc/           # R2DBC (NEW)
├── spring_vt/            # Virtual Threads
├── spring_platform/      # Platform Threads
├── spring_webflux_java/  # WebFlux (Java)
├── spring_webflux_coroutine/ # WebFlux (Kotlin)
├── docker/
│   ├── postgres/         # PostgreSQL + 초기 데이터
│   └── spring-base.Dockerfile
├── k6/                   # K6 테스트 스크립트
├── scripts/              # 벤치마크 자동화
└── reports/              # 성능 리포트
```

## 구현 단계

### [Step 1: 모듈 재설계](step1-module-redesign.md) (1일)
- data-jpa 모듈 생성 (Entity, Repository, Service)
- data-r2dbc 모듈 생성 (Entity, Repository, Service)
- business에 공통 DTO 추가
- settings.gradle.kts 업데이트

**검증**: `./gradlew build` 성공

### [Step 2: PostgreSQL Docker 설정](step2-postgresql-docker.md) (1일)
- PostgreSQL 17 Dockerfile + 성능 튜닝
- 스키마 정의 (init.sql)
- 1000만건 데이터 자동 생성 (seed-data.sql)
- docker-compose.yml (postgres 서비스)

**검증**: 데이터 생성 확인 (3-5분 소요)

### [Step 3: Spring Boot Docker 통합](step3-spring-docker-integration.md) (1일)
- Spring Boot Multi-stage Dockerfile
- docker-compose.yml 전체 서비스 추가 (1 CPU 1GB 제한)
- 각 Spring 모듈에 data 모듈 의존성 추가
- application.properties DB 설정

**검증**: `docker-compose up -d` 전체 실행 성공

### [Step 4: API 구현](step4-api-implementation.md) (1일)
- spring_vt: OrderController (JPA)
- spring_platform: OrderController (JPA)
- spring_webflux_java: OrderReactiveHandler (R2DBC)
- spring_webflux_coroutine: OrderCoroutineController (R2DBC)

**검증**: `curl http://localhost:8080/api/orders` 응답 확인

### [Step 5: K6 테스트](step5-k6-testing.md) (1일)
- k6/db-query.js (DB 조회 시나리오)
- k6/mixed-workload.js (Mixed 시나리오)
- scripts/run_db_benchmark.sh (자동화)

**검증**: K6 테스트 실행 및 JSON 결과 생성

### [Step 6: 리포팅](step6-reporting.md) (1일)
- scripts/generate_comparison_report.py (Python)
- scripts/full_benchmark.sh (통합 자동화)
- docker/README.md (Docker 사용법)

**검증**: Markdown 비교 리포트 생성 확인

## 빠른 시작 (구현 후)

### 1. 전체 빌드 및 실행
```bash
docker-compose up -d
```

### 2. 벤치마크 실행
```bash
./scripts/full_benchmark.sh
```

### 3. 결과 확인
```bash
cat reports/db-benchmark/COMPARISON-*.md
```

## 주요 파일 목록

### 새로 생성 (34개)
- data-jpa: 6개 파일
- data-r2dbc: 4개 파일
- business DTO: 1개 파일
- Docker: 6개 파일
- Spring Controllers: 4개 파일 + 4개 Config
- K6 테스트: 2개 파일
- Scripts: 3개 파일
- 문서: 2개 파일

### 수정 (9개)
- settings.gradle.kts
- 각 Spring 모듈 build.gradle.kts (4개)
- 각 Spring 모듈 application.properties (4개)

## 예상 결과

### 성능 가설
1. **spring_webflux_java / coroutine**: R2DBC non-blocking, 높은 동시성
2. **spring_vt**: Virtual threads로 blocking JDBC 효율적 처리
3. **spring_platform**: Platform threads, pool 제약

### 측정 지표
- **Latency**: P50, P95, P99
- **Throughput**: RPS
- **Error Rate**: 실패율
- **Resources**: CPU%, Memory

## 현재 진행 상황

- [ ] Step 1: 모듈 재설계
- [ ] Step 2: PostgreSQL Docker 설정
- [ ] Step 3: Spring Boot Docker 통합
- [ ] Step 4: API 구현
- [ ] Step 5: K6 테스트
- [ ] Step 6: 리포팅

## 참고 사항

- 각 step은 독립적으로 실행 가능
- Step 1-2는 순서대로 진행 필요
- Step 3-4는 Step 1-2 완료 후 진행
- Step 5-6은 Step 4 완료 후 진행

## 문의 및 이슈

각 step별 상세 문서를 참조하세요:
- [step1-module-redesign.md](step1-module-redesign.md)
- [step2-postgresql-docker.md](step2-postgresql-docker.md)
- [step3-spring-docker-integration.md](step3-spring-docker-integration.md)
- [step4-api-implementation.md](step4-api-implementation.md)
- [step5-k6-testing.md](step5-k6-testing.md)
- [step6-reporting.md](step6-reporting.md)
