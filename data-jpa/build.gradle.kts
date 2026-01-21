plugins {
    kotlin("jvm")
    kotlin("plugin.spring")
    kotlin("plugin.jpa") version "2.2.21"
    id("org.springframework.boot")
    id("io.spring.dependency-management")
}

tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
    enabled = false
}

tasks.named<Jar>("jar") {
    enabled = true
}

dependencies {
    implementation(project(":business"))

    api("org.springframework.boot:spring-boot-starter-data-jpa")
    api("org.postgresql:postgresql")

    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("org.jetbrains.kotlin:kotlin-stdlib")

    testImplementation(kotlin("test"))
}
