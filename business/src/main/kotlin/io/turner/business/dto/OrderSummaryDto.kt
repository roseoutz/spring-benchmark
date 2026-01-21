package io.turner.business.dto

import java.math.BigDecimal
import java.time.Instant

/**
 * 주문 요약 DTO - JPA와 R2DBC 공통으로 사용
 */
data class OrderSummaryDto(
    val orderId: Long,
    val customerName: String,
    val productName: String,
    val quantity: Int,
    val totalAmount: BigDecimal,
    val orderStatus: String,
    val orderDate: Instant
)
