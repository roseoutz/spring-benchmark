package io.turner.data.jpa.service

import io.turner.business.dto.OrderSummaryDto
import io.turner.data.jpa.repository.OrderRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Service
@Transactional(readOnly = true)
class OrderQueryService(
    private val orderRepository: OrderRepository
) {

    /**
     * 주문 요약 조회 (페이징)
     *
     * @param status 주문 상태 (예: DELIVERED)
     * @param sinceDate 조회 시작 날짜
     * @param page 페이지 번호 (0부터 시작)
     * @param size 페이지 크기
     * @return 주문 요약 페이지
     */
    fun findOrderSummaries(
        status: String,
        sinceDate: Instant,
        page: Int,
        size: Int
    ): Page<OrderSummaryDto> {
        val pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "orderDate"))
        return orderRepository.findOrderSummaries(status, sinceDate, pageable)
    }

    /**
     * 주문 개수 조회
     */
    fun countOrderSummaries(status: String, sinceDate: Instant): Long {
        return orderRepository.countOrderSummaries(status, sinceDate)
    }
}
