# Step 3: Spring Boot Docker 통합

## 목표
- Spring Boot 애플리케이션 Dockerfile 생성
- docker-compose.yml에 4개 Spring 서비스 추가
- 각 Spring 모듈에 data 모듈 의존성 추가
- application.properties에 PostgreSQL 연결 설정
- 1 CPU 1GB 리소스 제한 적용

## 작업 목록

### 3.1 Spring Boot Dockerfile 생성

#### 파일 생성
- [x] `/docker/spring-base.Dockerfile`

```dockerfile
# Multi-stage build
FROM gradle:8.5-jdk24 AS builder

WORKDIR /app

# Gradle wrapper 및 의존성 캐싱
COPY gradle/ gradle/
COPY gradlew .
COPY settings.gradle.kts .
COPY build.gradle.kts .

# 모듈별 build.gradle.kts 복사
COPY business/build.gradle.kts business/
COPY data-jpa/build.gradle.kts data-jpa/
COPY data-r2dbc/build.gradle.kts data-r2dbc/
COPY spring_vt/build.gradle.kts spring_vt/
COPY spring_platform/build.gradle.kts spring_platform/
COPY spring_webflux_java/build.gradle.kts spring_webflux_java/
COPY spring_webflux_coroutine/build.gradle.kts spring_webflux_coroutine/

# 의존성 다운로드 (캐싱)
RUN ./gradlew dependencies --no-daemon || true

# 전체 소스 복사
COPY . .

# 빌드 인자로 모듈 선택
ARG MODULE_NAME
RUN ./gradlew :${MODULE_NAME}:bootJar --no-daemon

# Runtime stage
FROM eclipse-temurin:24-jre-alpine

WORKDIR /app

# 빌드 인자
ARG MODULE_NAME
ENV MODULE_NAME=${MODULE_NAME}

# JAR 파일 복사
COPY --from=builder /app/${MODULE_NAME}/build/libs/*.jar app.jar

# JVM 튜닝 (1GB 메모리 제한에 맞춤)
ENV JAVA_OPTS="-Xms256m -Xmx768m \
    -XX:+UseZGC \
    -XX:+ZGenerational \
    -XX:MaxRAMPercentage=75.0 \
    -XX:+AlwaysPreTouch \
    -XX:+UseStringDeduplication"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

### 3.2 docker-compose.yml 전체 서비스 추가

#### 파일 수정
- [x] `/docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    build:
      context: ./docker/postgres
      dockerfile: Dockerfile
    container_name: vt-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: vt_benchmark
      POSTGRES_USER: vt_user
      POSTGRES_PASSWORD: vt_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '2.0'
          memory: 2G
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vt_user -d vt_benchmark"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 60s
    networks:
      - vt-network

  spring_vt:
    build:
      context: .
      dockerfile: docker/spring-base.Dockerfile
      args:
        MODULE_NAME: spring_vt
    container_name: vt-spring-vt
    ports:
      - "8080:8080"
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/vt_benchmark
      SPRING_DATASOURCE_USERNAME: vt_user
      SPRING_DATASOURCE_PASSWORD: vt_password
      SPRING_PROFILES_ACTIVE: docker
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '1.0'
          memory: 1G
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s
    networks:
      - vt-network

  spring_platform:
    build:
      context: .
      dockerfile: docker/spring-base.Dockerfile
      args:
        MODULE_NAME: spring_platform
    container_name: vt-spring-platform
    ports:
      - "8081:8080"
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/vt_benchmark
      SPRING_DATASOURCE_USERNAME: vt_user
      SPRING_DATASOURCE_PASSWORD: vt_password
      SPRING_PROFILES_ACTIVE: docker
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '1.0'
          memory: 1G
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s
    networks:
      - vt-network

  spring_webflux_java:
    build:
      context: .
      dockerfile: docker/spring-base.Dockerfile
      args:
        MODULE_NAME: spring_webflux_java
    container_name: vt-spring-webflux-java
    ports:
      - "8082:8080"
    environment:
      SPRING_R2DBC_URL: r2dbc:postgresql://postgres:5432/vt_benchmark
      SPRING_R2DBC_USERNAME: vt_user
      SPRING_R2DBC_PASSWORD: vt_password
      SPRING_PROFILES_ACTIVE: docker
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '1.0'
          memory: 1G
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s
    networks:
      - vt-network

  spring_webflux_coroutine:
    build:
      context: .
      dockerfile: docker/spring-base.Dockerfile
      args:
        MODULE_NAME: spring_webflux_coroutine
    container_name: vt-spring-webflux-coroutine
    ports:
      - "8083:8080"
    environment:
      SPRING_R2DBC_URL: r2dbc:postgresql://postgres:5432/vt_benchmark
      SPRING_R2DBC_USERNAME: vt_user
      SPRING_R2DBC_PASSWORD: vt_password
      SPRING_PROFILES_ACTIVE: docker
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '1.0'
          memory: 1G
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s
    networks:
      - vt-network

volumes:
  postgres_data:
    driver: local

networks:
  vt-network:
    driver: bridge
```

### 3.3 Spring 모듈 build.gradle.kts 업데이트

#### spring_vt/build.gradle.kts
- [x] 수정: data-jpa 의존성 추가

```kotlin
dependencies {
    implementation(project(":business"))
    implementation(project(":data-jpa"))  // NEW

    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    // ... 기존 의존성
}
```

#### spring_platform/build.gradle.kts
- [x] 수정: data-jpa 의존성 추가 (spring_vt와 동일)

#### spring_webflux_java/build.gradle.kts
- [x] 수정: data-r2dbc 의존성 추가

```kotlin
dependencies {
    implementation(project(":business"))
    implementation(project(":data-r2dbc"))  // NEW

    implementation("org.springframework.boot:spring-boot-starter-webflux")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    // ... 기존 의존성
}
```

#### spring_webflux_coroutine/build.gradle.kts
- [x] 수정: data-r2dbc 의존성 추가 (webflux_java와 동일)

### 3.4 application.properties 업데이트

#### spring_vt/src/main/resources/application.properties
- [x] 수정: PostgreSQL 설정 추가

```properties
spring.application.name=spring-vt
server.port=8080

# Virtual Threads
spring.threads.virtual.enabled=true

# Database (환경 변수로 오버라이드 가능)
spring.datasource.url=${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5432/vt_benchmark}
spring.datasource.username=${SPRING_DATASOURCE_USERNAME:vt_user}
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD:vt_password}
spring.datasource.driver-class-name=org.postgresql.Driver

# HikariCP
spring.datasource.hikari.maximum-pool-size=50
spring.datasource.hikari.minimum-idle=10
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.max-lifetime=1800000

# JPA
spring.jpa.open-in-view=false
spring.jpa.show-sql=false
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.properties.hibernate.jdbc.batch_size=20
spring.jpa.properties.hibernate.order_inserts=true
spring.jpa.properties.hibernate.order_updates=true

# Actuator
management.endpoints.web.exposure.include=health,info,metrics
management.endpoint.health.show-details=when-authorized
```

#### spring_platform/src/main/resources/application.properties
- [x] 수정: PostgreSQL 설정 추가 (spring_vt와 동일, virtual threads만 false)

```properties
spring.application.name=spring-platform
server.port=8080

# Platform Threads (Tomcat default)
spring.threads.virtual.enabled=false

# Database (spring_vt와 동일)
# ... 나머지 설정 동일
```

#### spring_webflux_java/src/main/resources/application.properties
- [x] 수정: R2DBC 설정 추가

```properties
spring.application.name=spring-webflux-java
server.port=8080

# R2DBC (환경 변수로 오버라이드 가능)
spring.r2dbc.url=${SPRING_R2DBC_URL:r2dbc:postgresql://localhost:5432/vt_benchmark}
spring.r2dbc.username=${SPRING_R2DBC_USERNAME:vt_user}
spring.r2dbc.password=${SPRING_R2DBC_PASSWORD:vt_password}

# R2DBC Pool
spring.r2dbc.pool.enabled=true
spring.r2dbc.pool.initial-size=10
spring.r2dbc.pool.max-size=50
spring.r2dbc.pool.max-idle-time=30m
spring.r2dbc.pool.max-acquire-time=30s
spring.r2dbc.pool.max-create-connection-time=30s

# WebFlux
spring.webflux.base-path=/

# Actuator
management.endpoints.web.exposure.include=health,info,metrics
management.endpoint.health.show-details=when-authorized
```

#### spring_webflux_coroutine/src/main/resources/application.properties
- [x] 수정: R2DBC 설정 추가 (webflux_java와 동일)

```properties
spring.application.name=spring-webflux-coroutine
server.port=8080

# R2DBC (webflux_java와 동일)
# ... 나머지 설정 동일
```

## 검증 방법

### Gradle 빌드 테스트
```bash
./gradlew clean build
```

### Docker 이미지 빌드 (개별)
```bash
docker-compose build spring_vt
docker-compose build spring_platform
docker-compose build spring_webflux_java
docker-compose build spring_webflux_coroutine
```

### Docker 이미지 빌드 (전체)
```bash
docker-compose build
```

### 전체 서비스 실행
```bash
docker-compose up -d

# 로그 확인
docker-compose logs -f

# Health check 대기
docker-compose ps
```

### Spring Actuator Health Check
```bash
curl http://localhost:8080/actuator/health
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
curl http://localhost:8083/actuator/health
```

### 리소스 제한 확인
```bash
docker stats --no-stream

# 각 Spring 컨테이너의 CPU %가 100% 넘지 않아야 함
# 메모리가 1GB 넘지 않아야 함
```

## 문제 해결

### 빌드 실패
```bash
# Gradle 캐시 정리
./gradlew clean --no-daemon

# Docker 빌드 캐시 삭제
docker-compose build --no-cache
```

### 메모리 부족 (OOMKilled)
- `JAVA_OPTS`의 `-Xmx` 값 조정 (현재 768m)
- Docker Compose의 메모리 제한 확인

### PostgreSQL 연결 실패
- postgres 서비스 health check 상태 확인
- 네트워크 설정 확인 (vt-network)
- 환경 변수 확인

### Port 충돌
```bash
# 포트 사용 확인
lsof -i :8080
lsof -i :8081
lsof -i :8082
lsof -i :8083
lsof -i :5432
```

## 예상 소요 시간
1일 (8시간)
- Dockerfile 작성: 2시간
- docker-compose.yml 작성: 2시간
- application.properties 설정: 2시간
- 빌드 및 검증: 2시간

## 다음 단계
Step 4: API 구현 (OrderController, OrderReactiveHandler 등)
