# Docker Setup Guide

Spring Boot Virtual Threads 성능 비교를 위한 Docker 환경 설정 가이드입니다.

## 사전 준비

### Docker Desktop 설치
- macOS/Windows: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Linux: [Docker Engine](https://docs.docker.com/engine/install/)

### 리소스 할당
Docker Desktop > Settings > Resources:
- **CPU**: 최소 6 cores (권장 8 cores)
- **Memory**: 최소 8GB (권장 12GB)
- **Swap**: 2GB
- **Disk**: 20GB 이상

## 빠른 시작

### 1. 전체 빌드 및 실행
```bash
docker-compose up -d
```

초기 실행 시 PostgreSQL 데이터 생성에 **3-5분** 소요됩니다.

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

## API 테스트

### Health Check
```bash
curl http://localhost:8080/actuator/health  # spring_vt
curl http://localhost:8081/actuator/health  # spring_platform
curl http://localhost:8082/actuator/health  # spring_webflux_java
curl http://localhost:8083/actuator/health  # spring_webflux_coroutine
```

### 주문 조회 API
```bash
curl "http://localhost:8080/api/orders?size=10" | jq .
curl "http://localhost:8081/api/orders?size=10" | jq .
curl "http://localhost:8082/api/orders?size=10" | jq .
curl "http://localhost:8083/api/orders?size=10" | jq .
```

### Workload API (기존)
```bash
curl "http://localhost:8080/api/workload?tasks=25&workMs=30" | jq .
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
3. `docker/spring-base.Dockerfile`의 JVM `-Xmx` 값 조정

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

## 포트 매핑

| Service | Container Port | Host Port | URL |
|---------|---------------|-----------|-----|
| postgres | 5432 | 5432 | postgresql://localhost:5432/vt_benchmark |
| spring_vt | 8080 | 8080 | http://localhost:8080 |
| spring_platform | 8080 | 8081 | http://localhost:8081 |
| spring_webflux_java | 8080 | 8082 | http://localhost:8082 |
| spring_webflux_coroutine | 8080 | 8083 | http://localhost:8083 |

## 리소스 제한

각 Spring 서비스는 다음 리소스로 제한됩니다:
- **CPU**: 1 core (정확히 1.0)
- **Memory**: 1GB

PostgreSQL은 다음 리소스를 사용합니다:
- **CPU**: 2 cores
- **Memory**: 2GB

## 참고 자료

- [Docker Compose CLI Reference](https://docs.docker.com/compose/reference/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
