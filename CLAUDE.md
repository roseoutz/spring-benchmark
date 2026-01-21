# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **virtual thread performance comparison project** for Spring Boot 4 / Java 24. The repository contains multiple Spring Boot applications to benchmark different concurrency models:

- `spring_vt` - Virtual threads (port 8080)
- `spring_platform` - Platform threads (port 8081)
- `spring_webflux_java` - WebFlux reactive (port 8082, Java)
- `spring_webflux_coroutine` - WebFlux with Kotlin coroutines (port 8083)

All applications share the same `business` module containing `WorkloadService`, which simulates I/O-bound work via `Thread.sleep()`.

## Build & Run Commands

### Build all projects
```bash
./gradlew build
```

### Run a specific application
```bash
./gradlew :spring_vt:bootRun
./gradlew :spring_platform:bootRun
./gradlew :spring_webflux_java:bootRun
./gradlew :spring_webflux_coroutine:bootRun
```

### Run tests
```bash
./gradlew test
./gradlew :spring_vt:test  # Single module
```

### Clean build
```bash
./gradlew clean build
```

## Architecture

### Multi-module Gradle Structure

- **`business/`** - Shared business logic module (pure Kotlin, no Spring)
  - Contains `WorkloadService` for simulating I/O work
  - Data classes: `WorkloadReport`, `TaskSample`
  - Shared DTOs: `OrderSummaryDto`

- **`data-jpa/`** - JPA/JDBC data access module
  - JPA entities: `Customer`, `Product`, `Order`
  - Repository: `OrderRepository` with 3-way JOIN queries
  - Service: `OrderQueryService`
  - Used by `spring_vt` and `spring_platform`

- **`data-r2dbc/`** - R2DBC reactive data access module
  - R2DBC entities: `CustomerR2dbc`, `ProductR2dbc`, `OrderR2dbc`
  - Repository: `OrderR2dbcRepository` with reactive queries
  - Service: `OrderQueryReactiveService`
  - Used by `spring_webflux_java` and `spring_webflux_coroutine`

- **`spring_vt/`** - Virtual thread implementation
  - Enables virtual threads via `spring.threads.virtual.enabled=true`
  - Uses standard Spring MVC with blocking controllers
  - JPA for database access

- **`spring_platform/`** - Platform thread baseline
  - Same as `spring_vt` but with `spring.threads.virtual.enabled=false`
  - For performance comparison
  - JPA for database access

- **`spring_webflux_java/`** - Reactive Java implementation
  - Pure Java (not Kotlin)
  - Uses Spring WebFlux for non-blocking I/O
  - R2DBC for reactive database access

- **`spring_webflux_coroutine/`** - Reactive Kotlin implementation
  - Uses Spring WebFlux + Kotlin coroutines
  - Suspend functions with reactive operators
  - R2DBC for reactive database access

### Key Configuration Differences

Each module uses identical REST API (`/api/workload`) but different threading models:

| Module | Threading | Port | Virtual Threads Enabled |
|--------|-----------|------|------------------------|
| spring_vt | Virtual threads | 8080 | true |
| spring_platform | Platform threads | 8081 | false |
| spring_webflux_java | Reactive | 8082 | N/A |
| spring_webflux_coroutine | Coroutines | 8083 | N/A |

### REST APIs

#### Workload API (CPU-bound simulation)

All applications expose `GET /api/workload`:
- `tasks` (optional, default 25) - Number of parallel tasks
- `workMs` (optional, default 30) - Simulated work duration per task

Example:
```bash
curl "http://localhost:8080/api/workload?tasks=100&workMs=50"
```

Response includes:
- `batchSize`, `simulatedWorkMs`
- `totalDurationMs`, `avgTaskMs`, `maxTaskMs`, `minTaskMs`
- `threadsObserved` - Count of distinct threads used
- `sample` - First 5 task samples with thread names

#### Orders API (DB I/O-bound)

All applications expose `GET /api/orders`:
- `status` (optional, default DELIVERED) - Order status filter
- `daysAgo` (optional, default 30) - Date range in days
- `page` (optional, default 0) - Page number
- `size` (optional, default 100) - Page size

Example:
```bash
curl "http://localhost:8080/api/orders?status=DELIVERED&daysAgo=30&page=0&size=100"
```

Response format:
- JPA modules (`spring_vt`, `spring_platform`): Spring Data Page object
- R2DBC modules (`spring_webflux_java`, `spring_webflux_coroutine`): Custom pagination map

The query performs a 3-way JOIN across:
- `orders` (10M records)
- `customers` (1M records)
- `products` (10K records)

## Technology Stack

- **Java 24** with `--enable-preview` for virtual threads
- **Kotlin 2.2.21** with Spring plugin
- **Spring Boot 4.0.1** (latest milestone)
- **Spring Modulith 2.0.1** - Application module structure
- **GraalVM Native Image** support configured
- **Gradle 9.2.1** multi-module build

## Development Notes

### Virtual Threads

Virtual threads (`spring_vt`) replace Tomcat's platform thread pool entirely when `spring.threads.virtual.enabled=true`. The framework creates a virtual thread per request instead of using a bounded thread pool.

### Performance Testing

The `reports/` directory contains performance test results comparing all four implementations. When adding new tests, follow the naming pattern: `{module-name}-{timestamp}.md`.

### GraalVM Native Image

All Spring modules include `org.graalvm.buildtools.native` plugin. Build native image:
```bash
./gradlew :spring_vt:nativeCompile
```

### Module Dependencies

Module dependency graph:
```
spring_vt          → data-jpa → business
spring_platform    → data-jpa → business
spring_webflux_java     → data-r2dbc → business
spring_webflux_coroutine → data-r2dbc → business
```

When modifying shared modules (`business`, `data-jpa`, `data-r2dbc`), rebuild all dependent modules.

## Docker Environment

### Quick Start

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### Services

The Docker environment includes:

| Service | Image | Port | Resources |
|---------|-------|------|-----------|
| postgres | PostgreSQL 17 | 5432 | 2 CPU, 2GB RAM |
| spring_vt | Custom | 8080 | 1 CPU, 1GB RAM |
| spring_platform | Custom | 8081 | 1 CPU, 1GB RAM |
| spring_webflux_java | Custom | 8082 | 1 CPU, 1GB RAM |
| spring_webflux_coroutine | Custom | 8083 | 1 CPU, 1GB RAM |

### Database

PostgreSQL is initialized with:
- **1,000,000** customers
- **10,000** products
- **10,000,000** orders (3-way JOIN performance testing)

Data generation takes **3-5 minutes** on first startup.

Access database:
```bash
docker exec -it vt-postgres psql -U vt_user -d vt_benchmark
```

### Docker Commands

```bash
# Build specific service
docker-compose build spring_vt

# Restart service
docker-compose restart spring_vt

# View service logs
docker-compose logs -f spring_vt

# Reset database (delete volume)
docker-compose down -v
docker-compose up postgres -d
```

See `docker/README.md` for detailed Docker documentation.

## Performance Testing with K6

### Quick Start

```bash
# Install K6
brew install k6  # macOS

# Run full benchmark
./scripts/full_benchmark.sh
```

### Test Scripts

- **`k6/db-query.js`** - Database query load test (3-way JOIN)
  - 20 VUs for 2 minutes
  - Tests `/api/orders` endpoint
  - Measures P50, P95, P99 latency

- **`k6/mixed-workload.js`** - Mixed CPU + DB workload
  - 15 VUs for DB queries
  - 5 VUs for CPU workload
  - Simulates realistic traffic

### Manual Testing

```bash
# Test specific adapter
ADAPTER=spring_vt k6 run k6/db-query.js
ADAPTER=spring_platform k6 run k6/db-query.js
ADAPTER=spring_webflux_java k6 run k6/db-query.js
ADAPTER=spring_webflux_coroutine k6 run k6/db-query.js
```

### Automated Benchmark

```bash
# Run all adapters and generate comparison report
./scripts/run_db_benchmark.sh
python3 scripts/generate_comparison_report.py reports/db-benchmark

# View latest report
ls -lt reports/db-benchmark/COMPARISON-*.md | head -1 | awk '{print $NF}' | xargs cat
```

See `k6/README.md` for detailed K6 documentation.

## Performance Reports

Results are saved in `reports/db-benchmark/`:
- `{adapter}-{timestamp}-raw.json` - Raw K6 metrics
- `{adapter}-{timestamp}-summary.json` - K6 summary
- `COMPARISON-{timestamp}.md` - Comparison report across all adapters
- `docker-stats-{timestamp}.txt` - Docker resource usage

## Development Workflow

### Local Development

```bash
# 1. Start PostgreSQL only
docker-compose up postgres -d

# 2. Run Spring app locally
./gradlew :spring_vt:bootRun

# 3. Test endpoint
curl "http://localhost:8080/api/orders?size=10" | jq .
```

### Full Docker Testing

```bash
# 1. Build and start everything
docker-compose up -d

# 2. Wait for health checks (check with docker-compose ps)

# 3. Run benchmark
./scripts/full_benchmark.sh

# 4. View results
cat reports/db-benchmark/COMPARISON-*.md
```

## Troubleshooting

### Docker Issues

```bash
# Check container health
docker-compose ps

# View container logs
docker-compose logs -f spring_vt

# Check resource usage
docker stats

# Rebuild with no cache
docker-compose build --no-cache spring_vt
```

### Database Issues

```bash
# Check data count
docker exec -it vt-postgres psql -U vt_user -d vt_benchmark -c "SELECT COUNT(*) FROM orders;"

# Re-initialize database
docker-compose down -v
docker-compose up postgres -d
```

### K6 Issues

```bash
# Verify K6 installation
k6 version

# Check script syntax
k6 inspect k6/db-query.js

# Run with verbose output
ADAPTER=spring_vt k6 run --verbose k6/db-query.js
```
