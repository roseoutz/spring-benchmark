package io.turner.data.jpa.entity

import jakarta.persistence.*

@Entity
@Table(
    name = "customers",
    indexes = [
        Index(name = "idx_customers_country", columnList = "country"),
        Index(name = "idx_customers_email", columnList = "email")
    ]
)
data class Customer(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "customer_id")
    val customerId: Long = 0,

    @Column(name = "email", nullable = false, unique = true, length = 255)
    val email: String,

    @Column(name = "name", nullable = false, length = 100)
    val name: String,

    @Column(name = "country", nullable = false, length = 50)
    val country: String
)
