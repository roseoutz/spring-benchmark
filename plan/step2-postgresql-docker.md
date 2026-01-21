# Step 2: PostgreSQL Docker 설정

## 목표
- PostgreSQL 17 Docker 이미지 설정
- 1000만건 테스트 데이터 자동 생성
- 성능 최적화 설정
- Health check 설정

## 작업 목록

### 2.1 PostgreSQL Dockerfile

#### 파일 생성
- [x] `/docker/postgres/Dockerfile`

```dockerfile
FROM postgres:17-alpine

ENV POSTGRES_DB=vt_benchmark
ENV POSTGRES_USER=vt_user
ENV POSTGRES_PASSWORD=vt_password

COPY postgresql.conf /etc/postgresql/postgresql.conf
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
COPY seed-data.sql /docker-entrypoint-initdb.d/02-seed-data.sql

CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
```

### 2.2 스키마 정의 (init.sql)

#### 파일 생성
- [x] `/docker/postgres/init.sql`

```sql
-- 데이터베이스 생성은 ENV로 자동 처리됨

-- 고객 테이블 (1M records)
CREATE TABLE customers (
    customer_id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL
);

CREATE INDEX idx_customers_country ON customers(country);
CREATE INDEX idx_customers_email ON customers(email);

-- 상품 테이블 (10K records)
CREATE TABLE products (
    product_id BIGSERIAL PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price NUMERIC(12, 2) NOT NULL
);

CREATE INDEX idx_products_category ON products(category);

-- 주문 테이블 (10M records)
CREATE TABLE orders (
    order_id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_date TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 인덱스 (JOIN 성능)
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_product_id ON orders(product_id);
CREATE INDEX idx_orders_status_date ON orders(order_status, order_date DESC);

-- 외래 키 (옵션, 성능 고려하여 제외 가능)
-- ALTER TABLE orders ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id);
-- ALTER TABLE orders ADD CONSTRAINT fk_orders_product FOREIGN KEY (product_id) REFERENCES products(product_id);
```

### 2.3 데이터 생성 (seed-data.sql)

#### 파일 생성
- [x] `/docker/postgres/seed-data.sql`

```sql
-- 1M 고객 생성 (약 10초)
INSERT INTO customers (email, name, country)
SELECT
    'customer' || i || '@example.com',
    'Customer ' || i,
    CASE (i % 10)
        WHEN 0 THEN 'USA'
        WHEN 1 THEN 'UK'
        WHEN 2 THEN 'Germany'
        WHEN 3 THEN 'France'
        WHEN 4 THEN 'Japan'
        WHEN 5 THEN 'Korea'
        WHEN 6 THEN 'China'
        WHEN 7 THEN 'Canada'
        WHEN 8 THEN 'Australia'
        ELSE 'India'
    END
FROM generate_series(1, 1000000) AS i;

-- 10K 상품 생성 (약 1초)
INSERT INTO products (product_name, category, price)
SELECT
    'Product ' || i,
    CASE (i % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Books'
        WHEN 3 THEN 'Food'
        ELSE 'Home'
    END,
    (RANDOM() * 1000 + 10)::NUMERIC(12, 2)
FROM generate_series(1, 10000) AS i;

-- 10M 주문 생성 (약 2-3분)
-- UNLOGGED table로 빠르게 생성 후 일반 테이블로 전환
CREATE UNLOGGED TABLE orders_temp (
    order_id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_date TIMESTAMP NOT NULL
);

INSERT INTO orders_temp (customer_id, product_id, quantity, total_amount, order_status, order_date)
SELECT
    (RANDOM() * 999999 + 1)::BIGINT,  -- 1 ~ 1,000,000
    (RANDOM() * 9999 + 1)::BIGINT,    -- 1 ~ 10,000
    (RANDOM() * 10 + 1)::INT,          -- 1 ~ 10
    (RANDOM() * 5000 + 100)::NUMERIC(12, 2),
    CASE (RANDOM() * 4)::INT
        WHEN 0 THEN 'PENDING'
        WHEN 1 THEN 'PROCESSING'
        WHEN 2 THEN 'DELIVERED'
        WHEN 3 THEN 'CANCELLED'
        ELSE 'DELIVERED'
    END,
    NOW() - (RANDOM() * INTERVAL '365 days')  -- 최근 1년
FROM generate_series(1, 10000000) AS i;

-- 일반 테이블로 데이터 이동
INSERT INTO orders SELECT * FROM orders_temp;

-- 임시 테이블 삭제
DROP TABLE orders_temp;

-- 통계 정보 업데이트 (쿼리 플래너 최적화)
VACUUM ANALYZE customers;
VACUUM ANALYZE products;
VACUUM ANALYZE orders;

-- 데이터 확인
SELECT 'Customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'Products', COUNT(*) FROM products
UNION ALL
SELECT 'Orders', COUNT(*) FROM orders;

-- 샘플 조인 쿼리 성능 확인
EXPLAIN ANALYZE
SELECT
    o.order_id, c.name, p.product_name, o.quantity, o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products p ON o.product_id = p.product_id
WHERE o.order_status = 'DELIVERED'
ORDER BY o.order_date DESC
LIMIT 100;
```

### 2.4 PostgreSQL 성능 튜닝

#### 파일 생성
- [x] `/docker/postgres/postgresql.conf`

```conf
# 메모리 설정 (Docker에 2GB 할당 가정)
shared_buffers = 512MB                # 전체 메모리의 25%
effective_cache_size = 1536MB         # 전체 메모리의 75%
maintenance_work_mem = 256MB          # VACUUM, CREATE INDEX 등
work_mem = 16MB                       # 정렬, 해시 조인 등

# Connection 설정
max_connections = 200                 # Spring 앱 4개 * 50 connections
superuser_reserved_connections = 3

# Query Planner
random_page_cost = 1.1                # SSD 가정
effective_io_concurrency = 200        # SSD 가정
default_statistics_target = 100

# WAL (Write-Ahead Logging) - 성능 최적화
wal_buffers = 16MB
checkpoint_completion_target = 0.9
wal_compression = on

# Logging (성능 분석용)
log_min_duration_statement = 1000     # 1초 이상 쿼리 로깅
log_line_prefix = '%t [%p]: '
log_timezone = 'UTC'

# Autovacuum (통계 유지)
autovacuum = on
autovacuum_max_workers = 3

# Locale
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.utf8'
lc_monetary = 'en_US.utf8'
lc_numeric = 'en_US.utf8'
lc_time = 'en_US.utf8'

# 기본 설정
default_text_search_config = 'pg_catalog.english'
```

### 2.5 docker-compose.yml (postgres만 먼저)

#### 파일 생성
- [x] `/docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    build:
      context: ./docker/postgres
      dockerfile: Dockerfile
    container_name: vt-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: vt_benchmark
      POSTGRES_USER: vt_user
      POSTGRES_PASSWORD: vt_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '2.0'
          memory: 2G
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vt_user -d vt_benchmark"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 60s
    networks:
      - vt-network

volumes:
  postgres_data:
    driver: local

networks:
  vt-network:
    driver: bridge
```

## 검증 방법

### Docker 빌드 테스트
```bash
cd /Users/turner/Desktop/git/vt
docker-compose build postgres
```

### PostgreSQL 실행 및 데이터 생성 확인
```bash
docker-compose up postgres -d

# 로그 확인 (데이터 생성 진행 상황)
docker-compose logs -f postgres

# Health check 대기 (약 3-5분)
docker-compose ps
```

### 데이터베이스 접속 및 확인
```bash
docker exec -it vt-postgres psql -U vt_user -d vt_benchmark

# SQL 명령어
\dt                          -- 테이블 목록
\di                          -- 인덱스 목록
SELECT COUNT(*) FROM customers;   -- 1000000
SELECT COUNT(*) FROM products;    -- 10000
SELECT COUNT(*) FROM orders;      -- 10000000

# JOIN 쿼리 성능 테스트
EXPLAIN ANALYZE
SELECT
    o.order_id, c.name, p.product_name, o.quantity, o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products p ON o.product_id = p.product_id
WHERE o.order_status = 'DELIVERED'
AND o.order_date >= NOW() - INTERVAL '30 days'
ORDER BY o.order_date DESC
LIMIT 100;

\q
```

### Docker Volume 확인
```bash
docker volume ls
docker volume inspect vt_postgres_data
```

## 문제 해결

### 데이터 생성이 너무 느린 경우
- `shared_buffers` 증가
- `maintenance_work_mem` 증가
- UNLOGGED table 사용 (현재 적용됨)

### 메모리 부족
- Docker Desktop에 더 많은 메모리 할당
- `shared_buffers` 감소

### 데이터 초기화 재실행
```bash
docker-compose down -v  # Volume 삭제
docker-compose up postgres -d
```

## 예상 소요 시간
1일 (8시간)
- Docker 설정: 2시간
- SQL 스크립트 작성: 3시간
- 데이터 생성 및 검증: 3시간

## 다음 단계
Step 3: Spring Boot Docker 통합
