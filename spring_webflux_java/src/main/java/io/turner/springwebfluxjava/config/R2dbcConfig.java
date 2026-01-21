package io.turner.springwebfluxjava.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.r2dbc.repository.config.EnableR2dbcRepositories;

@Configuration
@EnableR2dbcRepositories(basePackages = "io.turner.data.r2dbc.repository")
public class R2dbcConfig {
}
