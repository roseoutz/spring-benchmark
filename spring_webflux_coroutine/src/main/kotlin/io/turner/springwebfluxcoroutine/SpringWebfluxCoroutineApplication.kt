package io.turner.springwebfluxcoroutine

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication(scanBasePackages = ["io.turner"])
class SpringWebfluxCoroutineApplication

fun main(args: Array<String>) {
    runApplication<SpringWebfluxCoroutineApplication>(*args)
}
