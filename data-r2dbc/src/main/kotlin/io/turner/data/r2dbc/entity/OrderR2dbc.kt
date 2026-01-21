package io.turner.data.r2dbc.entity

import org.springframework.data.annotation.Id
import org.springframework.data.relational.core.mapping.Column
import org.springframework.data.relational.core.mapping.Table
import java.math.BigDecimal
import java.time.Instant

@Table("orders")
data class OrderR2dbc(
    @Id
    @Column("order_id")
    val orderId: Long = 0,

    @Column("customer_id")
    val customerId: Long,

    @Column("product_id")
    val productId: Long,

    @Column("quantity")
    val quantity: Int,

    @Column("total_amount")
    val totalAmount: BigDecimal,

    @Column("order_status")
    val orderStatus: String,

    @Column("order_date")
    val orderDate: Instant
)
