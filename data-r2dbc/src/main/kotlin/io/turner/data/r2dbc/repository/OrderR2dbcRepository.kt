package io.turner.data.r2dbc.repository

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.r2dbc.entity.OrderR2dbc
import org.springframework.data.r2dbc.repository.Query
import org.springframework.data.r2dbc.repository.R2dbcRepository
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import reactor.core.publisher.Flux
import reactor.core.publisher.Mono
import java.time.Instant

@Repository
interface OrderR2dbcRepository : R2dbcRepository<OrderR2dbc, Long> {

    /**
     * 3-way JOIN 쿼리로 Order, Customer, Product 조회
     * Native SQL 사용 (R2DBC는 JPQL 미지원)
     */
    @Query(
        """
        SELECT
            o.order_id,
            c.name as customer_name,
            p.product_name,
            o.quantity,
            o.total_amount,
            o.order_status,
            o.order_date
        FROM orders o
        JOIN customers c ON o.customer_id = c.customer_id
        JOIN products p ON o.product_id = p.product_id
        WHERE o.order_status = :status
        AND o.order_date >= :sinceDate
        ORDER BY o.order_date DESC
        LIMIT :limit OFFSET :offset
        """
    )
    fun findOrderSummaries(
        @Param("status") status: String,
        @Param("sinceDate") sinceDate: Instant,
        @Param("limit") limit: Int,
        @Param("offset") offset: Long
    ): Flux<OrderSummaryDto>

    /**
     * 카운트 쿼리 (페이징용)
     */
    @Query(
        """
        SELECT COUNT(*)
        FROM orders o
        WHERE o.order_status = :status
        AND o.order_date >= :sinceDate
        """
    )
    fun countOrderSummaries(
        @Param("status") status: String,
        @Param("sinceDate") sinceDate: Instant
    ): Mono<Long>
}
