package io.turner.data.r2dbc.entity

import org.springframework.data.annotation.Id
import org.springframework.data.relational.core.mapping.Column
import org.springframework.data.relational.core.mapping.Table
import java.math.BigDecimal

@Table("products")
data class ProductR2dbc(
    @Id
    @Column("product_id")
    val productId: Long = 0,

    @Column("product_name")
    val productName: String,

    @Column("category")
    val category: String,

    @Column("price")
    val price: BigDecimal
)
