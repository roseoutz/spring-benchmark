package io.turner.springwebfluxcoroutine.api

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.r2dbc.service.OrderQueryReactiveService
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.reactive.asFlow
import kotlinx.coroutines.reactive.awaitSingle
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.math.ceil

@RestController
@RequestMapping("/api/orders")
class OrderCoroutineController(
    private val orderQueryReactiveService: OrderQueryReactiveService
) {

    /**
     * 주문 목록 조회 (Coroutine)
     *
     * @param status 주문 상태 (기본: DELIVERED)
     * @param daysAgo 조회 기간 (기본: 30일)
     * @param page 페이지 번호 (기본: 0)
     * @param size 페이지 크기 (기본: 100)
     * @return 주문 요약 맵
     */
    @GetMapping
    suspend fun getOrders(
        @RequestParam(defaultValue = "DELIVERED") status: String,
        @RequestParam(defaultValue = "30") daysAgo: Long,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "100") size: Int
    ): Map<String, Any> {
        val sinceDate = Instant.now().minus(daysAgo, ChronoUnit.DAYS)

        val content = orderQueryReactiveService
            .findOrderSummaries(status, sinceDate, page, size)
            .asFlow()
            .toList()

        val totalElements = orderQueryReactiveService
            .countOrderSummaries(status, sinceDate)
            .awaitSingle()

        val totalPages = ceil(totalElements.toDouble() / size).toInt()

        return mapOf(
            "content" to content,
            "page" to page,
            "size" to size,
            "totalElements" to totalElements,
            "totalPages" to totalPages
        )
    }
}
