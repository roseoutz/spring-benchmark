package io.turner.springwebfluxjava.api;

import io.turner.business.dto.OrderSummaryDto;
import io.turner.data.r2dbc.service.OrderQueryReactiveService;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.server.ServerRequest;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;

@Component
public class OrderReactiveHandler {

    private final OrderQueryReactiveService orderQueryReactiveService;

    public OrderReactiveHandler(OrderQueryReactiveService orderQueryReactiveService) {
        this.orderQueryReactiveService = orderQueryReactiveService;
    }

    /**
     * 주문 목록 조회 (Reactive)
     *
     * @param request HTTP 요청
     * @return 주문 요약 응답
     */
    public Mono<ServerResponse> getOrders(ServerRequest request) {
        String status = request.queryParam("status").orElse("DELIVERED");
        long daysAgo = Long.parseLong(request.queryParam("daysAgo").orElse("30"));
        int page = Integer.parseInt(request.queryParam("page").orElse("0"));
        int size = Integer.parseInt(request.queryParam("size").orElse("100"));

        Instant sinceDate = Instant.now().minus(daysAgo, ChronoUnit.DAYS);

        return orderQueryReactiveService.findOrderSummaries(status, sinceDate, page, size)
            .collectList()
            .zipWith(orderQueryReactiveService.countOrderSummaries(status, sinceDate))
            .flatMap(tuple -> {
                var content = tuple.getT1();
                var totalElements = tuple.getT2();
                int totalPages = (int) Math.ceil((double) totalElements / size);

                var response = Map.of(
                    "content", content,
                    "page", page,
                    "size", size,
                    "totalElements", totalElements,
                    "totalPages", totalPages
                );

                return ServerResponse.ok().bodyValue(response);
            });
    }
}
