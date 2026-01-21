# Step 4: API 구현

## 목표
- spring_vt에 OrderController 구현 (blocking JPA)
- spring_platform에 OrderController 구현 (blocking JPA)
- spring_webflux_java에 OrderReactiveHandler 구현 (R2DBC Flux)
- spring_webflux_coroutine에 OrderCoroutineController 구현 (R2DBC Flow)
- 공통 API 스펙: `GET /api/orders?status=DELIVERED&daysAgo=30&page=0&size=100`

## 작업 목록

### 4.1 spring_vt - OrderController

#### 파일 생성
- [x] `/spring_vt/src/main/kotlin/io/turner/springvt/api/OrderController.kt`

```kotlin
package io.turner.springvt.api

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.jpa.service.OrderQueryService
import org.springframework.data.domain.Page
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.time.temporal.ChronoUnit

@RestController
@RequestMapping("/api/orders")
class OrderController(
    private val orderQueryService: OrderQueryService
) {

    @GetMapping
    fun getOrders(
        @RequestParam(defaultValue = "DELIVERED") status: String,
        @RequestParam(defaultValue = "30") daysAgo: Long,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "100") size: Int
    ): Page<OrderSummaryDto> {
        val sinceDate = Instant.now().minus(daysAgo, ChronoUnit.DAYS)
        return orderQueryService.findOrderSummaries(status, sinceDate, page, size)
    }
}
```

#### 파일 생성
- [x] `/spring_vt/src/main/kotlin/io/turner/springvt/config/JpaConfig.kt`

```kotlin
package io.turner.springvt.config

import org.springframework.boot.autoconfigure.domain.EntityScan
import org.springframework.context.annotation.Configuration
import org.springframework.data.jpa.repository.config.EnableJpaRepositories

@Configuration
@EnableJpaRepositories(basePackages = ["io.turner.data.jpa.repository"])
@EntityScan(basePackages = ["io.turner.data.jpa.entity"])
class JpaConfig
```

### 4.2 spring_platform - OrderController

#### 파일 생성
- [x] `/spring_platform/src/main/kotlin/io/turner/springplatform/api/OrderController.kt`

```kotlin
package io.turner.springplatform.api

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.jpa.service.OrderQueryService
import org.springframework.data.domain.Page
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.time.temporal.ChronoUnit

@RestController
@RequestMapping("/api/orders")
class OrderController(
    private val orderQueryService: OrderQueryService
) {

    @GetMapping
    fun getOrders(
        @RequestParam(defaultValue = "DELIVERED") status: String,
        @RequestParam(defaultValue = "30") daysAgo: Long,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "100") size: Int
    ): Page<OrderSummaryDto> {
        val sinceDate = Instant.now().minus(daysAgo, ChronoUnit.DAYS)
        return orderQueryService.findOrderSummaries(status, sinceDate, page, size)
    }
}
```

#### 파일 생성
- [x] `/spring_platform/src/main/kotlin/io/turner/springplatform/config/JpaConfig.kt`

```kotlin
package io.turner.springplatform.config

import org.springframework.boot.autoconfigure.domain.EntityScan
import org.springframework.context.annotation.Configuration
import org.springframework.data.jpa.repository.config.EnableJpaRepositories

@Configuration
@EnableJpaRepositories(basePackages = ["io.turner.data.jpa.repository"])
@EntityScan(basePackages = ["io.turner.data.jpa.entity"])
class JpaConfig
```

### 4.3 spring_webflux_java - OrderReactiveHandler

#### 파일 생성
- [x] `/spring_webflux_java/src/main/java/io/turner/springwebfluxjava/api/OrderReactiveHandler.java`

```java
package io.turner.springwebfluxjava.api;

import io.turner.business.dto.OrderSummaryDto;
import io.turner.data.r2dbc.service.OrderQueryReactiveService;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.server.ServerRequest;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;

@Component
public class OrderReactiveHandler {

    private final OrderQueryReactiveService orderQueryReactiveService;

    public OrderReactiveHandler(OrderQueryReactiveService orderQueryReactiveService) {
        this.orderQueryReactiveService = orderQueryReactiveService;
    }

    public Mono<ServerResponse> getOrders(ServerRequest request) {
        String status = request.queryParam("status").orElse("DELIVERED");
        long daysAgo = Long.parseLong(request.queryParam("daysAgo").orElse("30"));
        int page = Integer.parseInt(request.queryParam("page").orElse("0"));
        int size = Integer.parseInt(request.queryParam("size").orElse("100"));

        Instant sinceDate = Instant.now().minus(daysAgo, ChronoUnit.DAYS);

        return orderQueryReactiveService.findOrderSummaries(status, sinceDate, page, size)
            .collectList()
            .zipWith(orderQueryReactiveService.countOrderSummaries(status, sinceDate))
            .flatMap(tuple -> {
                var content = tuple.getT1();
                var totalElements = tuple.getT2();
                int totalPages = (int) Math.ceil((double) totalElements / size);

                var response = Map.of(
                    "content", content,
                    "page", page,
                    "size", size,
                    "totalElements", totalElements,
                    "totalPages", totalPages
                );

                return ServerResponse.ok().bodyValue(response);
            });
    }
}
```

#### 파일 생성
- [x] `/spring_webflux_java/src/main/java/io/turner/springwebfluxjava/config/RouterConfig.java`

```java
package io.turner.springwebfluxjava.config;

import io.turner.springwebfluxjava.api.OrderReactiveHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.server.RouterFunction;
import org.springframework.web.reactive.function.server.RouterFunctions;
import org.springframework.web.reactive.function.server.ServerResponse;

import static org.springframework.web.reactive.function.server.RequestPredicates.GET;

@Configuration
public class RouterConfig {

    @Bean
    public RouterFunction<ServerResponse> orderRoutes(OrderReactiveHandler handler) {
        return RouterFunctions.route(GET("/api/orders"), handler::getOrders);
    }
}
```

#### 파일 생성
- [x] `/spring_webflux_java/src/main/java/io/turner/springwebfluxjava/config/R2dbcConfig.java`

```java
package io.turner.springwebfluxjava.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.r2dbc.repository.config.EnableR2dbcRepositories;

@Configuration
@EnableR2dbcRepositories(basePackages = "io.turner.data.r2dbc.repository")
public class R2dbcConfig {
}
```

### 4.4 spring_webflux_coroutine - OrderCoroutineController

#### 파일 생성
- [x] `/spring_webflux_coroutine/src/main/kotlin/io/turner/springwebfluxcoroutine/api/OrderCoroutineController.kt`

```kotlin
package io.turner.springwebfluxcoroutine.api

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.r2dbc.service.OrderQueryReactiveService
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.reactive.asFlow
import kotlinx.coroutines.reactive.awaitSingle
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.math.ceil

@RestController
@RequestMapping("/api/orders")
class OrderCoroutineController(
    private val orderQueryReactiveService: OrderQueryReactiveService
) {

    @GetMapping
    suspend fun getOrders(
        @RequestParam(defaultValue = "DELIVERED") status: String,
        @RequestParam(defaultValue = "30") daysAgo: Long,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "100") size: Int
    ): Map<String, Any> {
        val sinceDate = Instant.now().minus(daysAgo, ChronoUnit.DAYS)

        val content = orderQueryReactiveService
            .findOrderSummaries(status, sinceDate, page, size)
            .asFlow()
            .toList()

        val totalElements = orderQueryReactiveService
            .countOrderSummaries(status, sinceDate)
            .awaitSingle()

        val totalPages = ceil(totalElements.toDouble() / size).toInt()

        return mapOf(
            "content" to content,
            "page" to page,
            "size" to size,
            "totalElements" to totalElements,
            "totalPages" to totalPages
        )
    }
}
```

#### 파일 생성
- [x] `/spring_webflux_coroutine/src/main/kotlin/io/turner/springwebfluxcoroutine/config/R2dbcConfig.kt`

```kotlin
package io.turner.springwebfluxcoroutine.config

import org.springframework.context.annotation.Configuration
import org.springframework.data.r2dbc.repository.config.EnableR2dbcRepositories

@Configuration
@EnableR2dbcRepositories(basePackages = ["io.turner.data.r2dbc.repository"])
class R2dbcConfig
```

## 검증 방법

### Gradle 빌드 테스트
```bash
./gradlew :spring_vt:build
./gradlew :spring_platform:build
./gradlew :spring_webflux_java:build
./gradlew :spring_webflux_coroutine:build
```

### 로컬 실행 테스트 (PostgreSQL 필요)
```bash
# PostgreSQL 실행
docker-compose up postgres -d

# spring_vt 실행
./gradlew :spring_vt:bootRun

# 다른 터미널에서 테스트
curl "http://localhost:8080/api/orders?size=10" | jq .
```

### Docker 전체 실행 테스트
```bash
docker-compose up -d

# Health check 대기
sleep 60

# API 테스트
curl "http://localhost:8080/api/orders?size=10" | jq .
curl "http://localhost:8081/api/orders?size=10" | jq .
curl "http://localhost:8082/api/orders?size=10" | jq .
curl "http://localhost:8083/api/orders?size=10" | jq .
```

### 응답 형식 확인
```bash
# JPA (spring_vt, spring_platform)
curl "http://localhost:8080/api/orders?size=5" | jq '.'
# Expected:
# {
#   "content": [...],
#   "pageable": {...},
#   "totalPages": 123,
#   "totalElements": 12345,
#   "size": 5,
#   "number": 0
# }

# R2DBC (spring_webflux_java, spring_webflux_coroutine)
curl "http://localhost:8082/api/orders?size=5" | jq '.'
# Expected:
# {
#   "content": [...],
#   "page": 0,
#   "size": 5,
#   "totalElements": 12345,
#   "totalPages": 2469
# }
```

### 성능 간단 테스트
```bash
# Apache Bench
ab -n 100 -c 10 "http://localhost:8080/api/orders?size=100"
ab -n 100 -c 10 "http://localhost:8081/api/orders?size=100"
ab -n 100 -c 10 "http://localhost:8082/api/orders?size=100"
ab -n 100 -c 10 "http://localhost:8083/api/orders?size=100"
```

### PostgreSQL 쿼리 모니터링
```bash
docker exec -it vt-postgres psql -U vt_user -d vt_benchmark

-- 실행 중인 쿼리 확인
SELECT pid, state, query, query_start
FROM pg_stat_activity
WHERE datname = 'vt_benchmark'
AND state = 'active'
ORDER BY query_start DESC;

-- 느린 쿼리 로그 확인 (1초 이상)
SELECT * FROM pg_stat_statements
WHERE mean_exec_time > 1000
ORDER BY mean_exec_time DESC
LIMIT 10;
```

## 문제 해결

### JPA 매핑 오류
- `@EntityScan` 패키지 경로 확인
- Entity 클래스의 `@Table` 이름 확인

### R2DBC 연결 오류
- `spring.r2dbc.url` 형식 확인 (r2dbc:postgresql://...)
- R2DBC Pool 설정 확인

### JSON 직렬화 오류
- `java.time.Instant` 직렬화 확인
- Jackson 설정 확인

### 페이징 결과 불일치
- JPA: `Page<T>` 자동 형식
- R2DBC: 수동 페이징 형식 (Map)

## 예상 소요 시간
1일 (8시간)
- OrderController 구현 (JPA x2): 2시간
- OrderReactiveHandler 구현 (Java): 2시간
- OrderCoroutineController 구현 (Kotlin): 2시간
- 테스트 및 검증: 2시간

## 다음 단계
Step 5: K6 테스트 스크립트 작성
