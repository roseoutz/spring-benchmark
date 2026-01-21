# Step 1: 모듈 재설계

## 목표
- data-jpa 모듈 생성 (JPA + JDBC for spring_vt, spring_platform)
- data-r2dbc 모듈 생성 (R2DBC for webflux)
- business 모듈에 공통 DTO 추가
- 모듈 간 의존성 설정

## 작업 목록

### 1.1 data-jpa 모듈 생성

#### 파일 생성
- [x] `/data-jpa/build.gradle.kts`
- [x] `/data-jpa/src/main/kotlin/io/turner/data/jpa/entity/Customer.kt`
- [x] `/data-jpa/src/main/kotlin/io/turner/data/jpa/entity/Product.kt`
- [x] `/data-jpa/src/main/kotlin/io/turner/data/jpa/entity/Order.kt`
- [x] `/data-jpa/src/main/kotlin/io/turner/data/jpa/repository/OrderRepository.kt`
- [x] `/data-jpa/src/main/kotlin/io/turner/data/jpa/service/OrderQueryService.kt`

#### Entity 설계
```kotlin
@Entity
@Table(name = "customers", indexes = [...])
data class Customer(
    @Id @GeneratedValue val customerId: Long = 0,
    val email: String,
    val name: String,
    val country: String
)

@Entity
@Table(name = "products")
data class Product(
    @Id @GeneratedValue val productId: Long = 0,
    val productName: String,
    val category: String,
    val price: BigDecimal
)

@Entity
@Table(name = "orders", indexes = [...])
data class Order(
    @Id @GeneratedValue val orderId: Long = 0,
    val customerId: Long,
    val productId: Long,
    val quantity: Int,
    val totalAmount: BigDecimal,
    val orderStatus: String,
    val orderDate: Instant
)
```

#### Repository 쿼리
```kotlin
interface OrderRepository : JpaRepository<Order, Long> {
    @Query("""
        SELECT new io.turner.business.dto.OrderSummaryDto(
            o.orderId, c.name, p.productName, o.quantity,
            o.totalAmount, o.orderStatus, o.orderDate
        )
        FROM Order o
        JOIN Customer c ON o.customerId = c.customerId
        JOIN Product p ON o.productId = p.productId
        WHERE o.orderStatus = :status
        AND o.orderDate >= :sinceDate
    """)
    fun findOrderSummaries(
        status: String,
        sinceDate: Instant,
        pageable: Pageable
    ): Page<OrderSummaryDto>
}
```

### 1.2 data-r2dbc 모듈 생성

#### 파일 생성
- [x] `/data-r2dbc/build.gradle.kts`
- [x] `/data-r2dbc/src/main/kotlin/io/turner/data/r2dbc/entity/CustomerR2dbc.kt`
- [x] `/data-r2dbc/src/main/kotlin/io/turner/data/r2dbc/entity/ProductR2dbc.kt`
- [x] `/data-r2dbc/src/main/kotlin/io/turner/data/r2dbc/entity/OrderR2dbc.kt`
- [x] `/data-r2dbc/src/main/kotlin/io/turner/data/r2dbc/repository/OrderR2dbcRepository.kt`
- [x] `/data-r2dbc/src/main/kotlin/io/turner/data/r2dbc/service/OrderQueryReactiveService.kt`

#### R2DBC Entity 설계
```kotlin
@Table("orders")
data class OrderR2dbc(
    @Id val orderId: Long = 0,
    val customerId: Long,
    val productId: Long,
    val quantity: Int,
    val totalAmount: BigDecimal,
    val orderStatus: String,
    val orderDate: Instant
)
```

#### Repository 쿼리 (Native SQL)
```kotlin
interface OrderR2dbcRepository : R2dbcRepository<OrderR2dbc, Long> {
    @Query("""
        SELECT
            o.order_id, c.name as customer_name, p.product_name,
            o.quantity, o.total_amount, o.order_status, o.order_date
        FROM orders o
        JOIN customers c ON o.customer_id = c.customer_id
        JOIN products p ON o.product_id = p.product_id
        WHERE o.order_status = :status
        AND o.order_date >= :sinceDate
        ORDER BY o.order_date DESC
        LIMIT :limit OFFSET :offset
    """)
    fun findOrderSummaries(
        status: String,
        sinceDate: Instant,
        limit: Int,
        offset: Long
    ): Flux<OrderSummaryDto>

    @Query("""
        SELECT COUNT(*)
        FROM orders o
        WHERE o.order_status = :status
        AND o.order_date >= :sinceDate
    """)
    fun countOrderSummaries(status: String, sinceDate: Instant): Mono<Long>
}
```

### 1.3 공통 DTO 생성

#### 파일 생성
- [x] `/business/src/main/kotlin/io/turner/business/dto/OrderSummaryDto.kt`

```kotlin
package io.turner.business.dto

import java.math.BigDecimal
import java.time.Instant

data class OrderSummaryDto(
    val orderId: Long,
    val customerName: String,
    val productName: String,
    val quantity: Int,
    val totalAmount: BigDecimal,
    val orderStatus: String,
    val orderDate: Instant
)
```

### 1.4 settings.gradle.kts 업데이트

#### 파일 수정
- [x] `/settings.gradle.kts`

```kotlin
include(
    "business",
    "data-jpa",        // NEW
    "data-r2dbc",      // NEW
    "spring_vt",
    "spring_platform",
    "spring_webflux_java",
    "spring_webflux_coroutine",
)
```

## 검증 방법

### Gradle 빌드 테스트
```bash
./gradlew clean build
```

### 모듈 의존성 확인
```bash
./gradlew :data-jpa:dependencies
./gradlew :data-r2dbc:dependencies
```

### 컴파일 성공 확인
```bash
./gradlew :data-jpa:compileKotlin
./gradlew :data-r2dbc:compileKotlin
```

## 예상 소요 시간
1일 (8시간)

## 다음 단계
Step 2: PostgreSQL Docker 설정
