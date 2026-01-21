package io.turner.springwebfluxjava.config;

import io.turner.springwebfluxjava.api.OrderReactiveHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.server.RouterFunction;
import org.springframework.web.reactive.function.server.RouterFunctions;
import org.springframework.web.reactive.function.server.ServerResponse;

import static org.springframework.web.reactive.function.server.RequestPredicates.GET;

@Configuration
public class RouterConfig {

    @Bean
    public RouterFunction<ServerResponse> orderRoutes(OrderReactiveHandler handler) {
        return RouterFunctions.route(GET("/api/orders"), handler::getOrders);
    }
}
