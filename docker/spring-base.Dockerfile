# ===================================================================
# Multi-stage Dockerfile for Spring Boot Applications
# Stage 1: Builder (Gradle build)
# Stage 2: Runtime (JRE only)
# ===================================================================

# ===================================================================
# Builder Stage
# ===================================================================
FROM eclipse-temurin:24-jdk AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gradle wrapper 복사 (캐싱 최적화)
COPY gradlew .
RUN chmod +x gradlew
COPY gradle gradle/

# 빌드 스크립트 복사 (의존성 캐싱)
COPY settings.gradle.kts .
COPY build.gradle.kts .

# 모든 모듈의 build.gradle.kts 복사
COPY business/build.gradle.kts business/
COPY data-jpa/build.gradle.kts data-jpa/
COPY data-r2dbc/build.gradle.kts data-r2dbc/
COPY spring_vt/build.gradle.kts spring_vt/
COPY spring_platform/build.gradle.kts spring_platform/
COPY spring_webflux_java/build.gradle.kts spring_webflux_java/
COPY spring_webflux_coroutine/build.gradle.kts spring_webflux_coroutine/

# 의존성 다운로드 (캐싱 레이어)
RUN ./gradlew dependencies --no-daemon || true

# 전체 소스 코드 복사
COPY . .

# 빌드 인자로 모듈 이름 받기
ARG MODULE_NAME

# bootJar 빌드 (테스트 제외)
RUN ./gradlew :${MODULE_NAME}:bootJar -x test --no-daemon

# ===================================================================
# Runtime Stage
# ===================================================================
FROM eclipse-temurin:24-jre-alpine

WORKDIR /app

# 빌드 인자
ARG MODULE_NAME
ENV MODULE_NAME=${MODULE_NAME}

# JAR 파일 복사
COPY --from=builder /app/${MODULE_NAME}/build/libs/*.jar app.jar

# JVM 튜닝 (1GB 메모리 제한에 최적화)
ENV JAVA_OPTS="-Xms256m \
    -Xmx768m \
    -XX:+UseZGC \
    -XX:+ZGenerational \
    -XX:MaxRAMPercentage=75.0 \
    -XX:+AlwaysPreTouch \
    -XX:+UseStringDeduplication \
    -Djava.security.egd=file:/dev/./urandom"

# 포트 노출 (Spring Boot 기본 8080)
EXPOSE 8080

# Health check용 wget 설치
RUN apk add --no-cache wget

# 애플리케이션 실행
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
