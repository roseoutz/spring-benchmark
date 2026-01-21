package io.turner.data.jpa.entity

import jakarta.persistence.*
import java.math.BigDecimal

@Entity
@Table(
    name = "products",
    indexes = [
        Index(name = "idx_products_category", columnList = "category")
    ]
)
data class Product(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "product_id")
    val productId: Long = 0,

    @Column(name = "product_name", nullable = false, length = 200)
    val productName: String,

    @Column(name = "category", nullable = false, length = 50)
    val category: String,

    @Column(name = "price", nullable = false, precision = 12, scale = 2)
    val price: BigDecimal
)
