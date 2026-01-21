package io.turner.springplatform

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication(scanBasePackages = ["io.turner"])
class SpringPlatformApplication

fun main(args: Array<String>) {
    runApplication<SpringPlatformApplication>(*args)
}
