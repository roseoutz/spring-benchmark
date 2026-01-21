package io.turner.data.r2dbc.entity

import org.springframework.data.annotation.Id
import org.springframework.data.relational.core.mapping.Column
import org.springframework.data.relational.core.mapping.Table

@Table("customers")
data class CustomerR2dbc(
    @Id
    @Column("customer_id")
    val customerId: Long = 0,

    @Column("email")
    val email: String,

    @Column("name")
    val name: String,

    @Column("country")
    val country: String
)
