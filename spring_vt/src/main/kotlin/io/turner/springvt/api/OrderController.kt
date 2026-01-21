package io.turner.springvt.api

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.jpa.service.OrderQueryService
import org.springframework.data.domain.Page
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.time.temporal.ChronoUnit

@RestController
@RequestMapping("/api/orders")
class OrderController(
    private val orderQueryService: OrderQueryService
) {

    /**
     * 주문 목록 조회 (페이징)
     *
     * @param status 주문 상태 (기본: DELIVERED)
     * @param daysAgo 조회 기간 (기본: 30일)
     * @param page 페이지 번호 (기본: 0)
     * @param size 페이지 크기 (기본: 100)
     * @return 주문 요약 페이지
     */
    @GetMapping
    fun getOrders(
        @RequestParam(defaultValue = "DELIVERED") status: String,
        @RequestParam(defaultValue = "30") daysAgo: Long,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "100") size: Int
    ): Page<OrderSummaryDto> {
        val sinceDate = Instant.now().minus(daysAgo, ChronoUnit.DAYS)
        return orderQueryService.findOrderSummaries(status, sinceDate, page, size)
    }
}
