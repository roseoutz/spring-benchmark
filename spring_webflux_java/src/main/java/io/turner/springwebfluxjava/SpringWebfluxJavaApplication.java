package io.turner.springwebfluxjava;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "io.turner")
public class SpringWebfluxJavaApplication {

    public static void main(String[] args) {
        SpringApplication.run(SpringWebfluxJavaApplication.class, args);
    }
}
