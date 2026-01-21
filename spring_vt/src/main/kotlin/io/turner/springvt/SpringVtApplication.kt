package io.turner.springvt

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication(scanBasePackages = ["io.turner"])
class SpringVtApplication

fun main(args: Array<String>) {
    runApplication<SpringVtApplication>(*args)
}
