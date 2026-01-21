package io.turner.data.jpa.entity

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.Instant

@Entity
@Table(
    name = "orders",
    indexes = [
        Index(name = "idx_orders_customer_id", columnList = "customer_id"),
        Index(name = "idx_orders_product_id", columnList = "product_id"),
        Index(name = "idx_orders_status_date", columnList = "order_status,order_date")
    ]
)
data class Order(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "order_id")
    val orderId: Long = 0,

    @Column(name = "customer_id", nullable = false)
    val customerId: Long,

    @Column(name = "product_id", nullable = false)
    val productId: Long,

    @Column(name = "quantity", nullable = false)
    val quantity: Int,

    @Column(name = "total_amount", nullable = false, precision = 12, scale = 2)
    val totalAmount: BigDecimal,

    @Column(name = "order_status", nullable = false, length = 20)
    val orderStatus: String,

    @Column(name = "order_date", nullable = false)
    val orderDate: Instant = Instant.now()
)
