package io.turner.data.r2dbc.service

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.r2dbc.repository.OrderR2dbcRepository
import org.springframework.stereotype.Service
import reactor.core.publisher.Flux
import reactor.core.publisher.Mono
import java.time.Instant

@Service
class OrderQueryReactiveService(
    private val orderR2dbcRepository: OrderR2dbcRepository
) {

    /**
     * 주문 요약 조회 (페이징)
     *
     * @param status 주문 상태 (예: DELIVERED)
     * @param sinceDate 조회 시작 날짜
     * @param page 페이지 번호 (0부터 시작)
     * @param size 페이지 크기
     * @return 주문 요약 Flux
     */
    fun findOrderSummaries(
        status: String,
        sinceDate: Instant,
        page: Int,
        size: Int
    ): Flux<OrderSummaryDto> {
        val offset = page.toLong() * size
        return orderR2dbcRepository.findOrderSummaries(status, sinceDate, size, offset)
    }

    /**
     * 주문 개수 조회
     */
    fun countOrderSummaries(status: String, sinceDate: Instant): Mono<Long> {
        return orderR2dbcRepository.countOrderSummaries(status, sinceDate)
    }
}
