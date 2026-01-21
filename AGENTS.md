# Repository Guidelines

## Project Structure & Module Organization
The project is now a Gradle multi-module workspace. Shared business logic lives in the `business` module and must remain framework agnostic. Runtime adapters live in dedicated modules: `spring_vt` (Servlet + virtual threads), `spring_platform` (traditional platform threads), `spring_webflux_java` (Java WebFlux), and `spring_webflux_coroutine` (Kotlin WebFlux + coroutines). Keep each module's sources under its own `src/main/...` tree and mirror packages under `src/test/...` for specs. Shared abstractions belong in the `business` module (or a new `common` module) so module boundaries stay clear. Keep Gradle wrapper files (`gradlew*`, `gradle/`) untouched so every agent builds against the same toolchain (Java 24).

## Build, Test, and Development Commands
- `./gradlew :spring_vt:bootRun` – starts the MVC service locally with virtual threads enabled.
- `./gradlew :spring_platform:bootRun` – starts the MVC service on platform threads.
- `./gradlew :spring_webflux_java:bootRun` / `:spring_webflux_coroutine:bootRun` – start the respective WebFlux adapters.
- `./gradlew build` – compiles Kotlin, runs all tests, and produces `build/libs/vt-*.jar`.
- `./gradlew test` – quickest verification path; executes unit and Modulith tests only.
- `./gradlew bootBuildImage` – creates a Cloud Native Buildpack container (requires Docker).
- `./gradlew nativeCompile` / `nativeTest` – builds and validates GraalVM native binaries; run when touching startup-sensitive code.

## Coding Style & Naming Conventions
Adhere to the official Kotlin style guide: four-space indentation, trailing commas where supported, and `val` over `var` unless mutation is intentional. Classes, components, and configuration properties use `PascalCase`, while methods and parameters stay `camelCase`. Package names remain lowercase and align with module boundaries (`io.turner.<module>`). Keep controllers thin, push business logic into services, and annotate configuration classes (`@ConfigurationProperties`) so the Spring processor can emit metadata.

## Testing Guidelines
JUnit 5, `spring-boot-starter-webmvc-test`, and Spring Modulith test utilities are already wired through Gradle. Name test classes `SomethingTests` and place integration-level specs beside the module they cover. Prefer slices (`@WebMvcTest`, `ApplicationModuleTest`) for fast feedback; reserve full context loads for cross-module flows. Add regression tests for every bug fix, guard REST contracts with MockMvc or HTTP-driven tests, and run `./gradlew test` before every push. Execute `nativeTest` when a change affects startup hooks, serialization, or reflection.

## Commit & Pull Request Guidelines
Current history favors concise, imperative subject lines; keep the first line under 72 characters and explain the "why" in the body (e.g., `Add inventory module skeleton`). Reference related issues, list the Gradle commands you ran, and include screenshots for user-facing deltas. PRs should describe architecture impacts, highlight new configuration keys, and call out manual steps reviewers must try. Request review from the owning module lead, wait for CI green, and avoid force-pushing after feedback unless you also leave a summary comment.
