package io.turner.data.jpa.repository

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.jpa.entity.Order
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.time.Instant

@Repository
interface OrderRepository : JpaRepository<Order, Long> {

    /**
     * 3-way JOIN 쿼리로 Order, Customer, Product 조회
     * DTO projection으로 N+1 문제 방지
     */
    @Query(
        """
        SELECT new io.turner.business.dto.OrderSummaryDto(
            o.orderId, c.name, p.productName, o.quantity,
            o.totalAmount, o.orderStatus, o.orderDate
        )
        FROM Order o
        JOIN Customer c ON o.customerId = c.customerId
        JOIN Product p ON o.productId = p.productId
        WHERE o.orderStatus = :status
        AND o.orderDate >= :sinceDate
        ORDER BY o.orderDate DESC
        """
    )
    fun findOrderSummaries(
        @Param("status") status: String,
        @Param("sinceDate") sinceDate: Instant,
        pageable: Pageable
    ): Page<OrderSummaryDto>

    /**
     * 카운트 쿼리 (페이징용)
     */
    @Query(
        """
        SELECT COUNT(o)
        FROM Order o
        WHERE o.orderStatus = :status
        AND o.orderDate >= :sinceDate
        """
    )
    fun countOrderSummaries(
        @Param("status") status: String,
        @Param("sinceDate") sinceDate: Instant
    ): Long
}
