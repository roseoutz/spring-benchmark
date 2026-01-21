-- Spring Boot Virtual Threads Performance Test Data Generation
-- 1M customers + 10K products + 10M orders
-- 예상 소요 시간: 3-5분

\echo 'Starting data generation...'
\echo '======================================'

-- ===================================================================
-- 1. 고객 데이터 생성 (1M records, ~10초)
-- ===================================================================
\echo '1/3: Generating 1,000,000 customers...'

INSERT INTO customers (email, name, country)
SELECT
    'customer' || i || '@example.com' AS email,
    'Customer ' || i AS name,
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
    END AS country
FROM generate_series(1, 1000000) AS i;

\echo 'Customers created: 1,000,000'

-- ===================================================================
-- 2. 상품 데이터 생성 (10K records, ~1초)
-- ===================================================================
\echo '2/3: Generating 10,000 products...'

INSERT INTO products (product_name, category, price)
SELECT
    'Product ' || i AS product_name,
    CASE (i % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Books'
        WHEN 3 THEN 'Food'
        ELSE 'Home'
    END AS category,
    (RANDOM() * 1000 + 10)::NUMERIC(12, 2) AS price
FROM generate_series(1, 10000) AS i;

\echo 'Products created: 10,000'

-- ===================================================================
-- 3. 주문 데이터 생성 (10M records, ~2-3분)
-- ===================================================================
\echo '3/3: Generating 10,000,000 orders (this may take 2-3 minutes)...'

-- UNLOGGED TABLE로 빠르게 생성 후 일반 테이블로 전환
CREATE UNLOGGED TABLE orders_temp (
    order_id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_date TIMESTAMP NOT NULL
);

-- 10M 레코드 생성
INSERT INTO orders_temp (customer_id, product_id, quantity, total_amount, order_status, order_date)
SELECT
    (RANDOM() * 999999 + 1)::BIGINT AS customer_id,  -- 1 ~ 1,000,000
    (RANDOM() * 9999 + 1)::BIGINT AS product_id,      -- 1 ~ 10,000
    (RANDOM() * 10 + 1)::INT AS quantity,              -- 1 ~ 10
    (RANDOM() * 5000 + 100)::NUMERIC(12, 2) AS total_amount,
    CASE (RANDOM() * 4)::INT
        WHEN 0 THEN 'PENDING'
        WHEN 1 THEN 'PROCESSING'
        WHEN 2 THEN 'DELIVERED'
        WHEN 3 THEN 'CANCELLED'
        ELSE 'DELIVERED'
    END AS order_status,
    NOW() - (RANDOM() * INTERVAL '365 days') AS order_date  -- 최근 1년
FROM generate_series(1, 10000000) AS i;

\echo 'Orders generated in temporary table'

-- 임시 테이블에서 실제 orders 테이블로 데이터 이동
\echo 'Transferring orders to main table...'
INSERT INTO orders SELECT * FROM orders_temp;

-- 임시 테이블 삭제
DROP TABLE orders_temp;

\echo 'Orders created: 10,000,000'

-- ===================================================================
-- 4. 통계 정보 업데이트 (Query Planner 최적화)
-- ===================================================================
\echo '======================================'
\echo 'Updating table statistics...'

VACUUM ANALYZE customers;
VACUUM ANALYZE products;
VACUUM ANALYZE orders;

\echo 'Statistics updated'

-- ===================================================================
-- 5. 데이터 생성 결과 확인
-- ===================================================================
\echo '======================================'
\echo 'Data Generation Summary:'
\echo '======================================'

SELECT 'customers' AS table_name, COUNT(*)::TEXT AS row_count FROM customers
UNION ALL
SELECT 'products', COUNT(*)::TEXT FROM products
UNION ALL
SELECT 'orders', COUNT(*)::TEXT FROM orders;

\echo '======================================'

-- ===================================================================
-- 6. 샘플 쿼리 성능 테스트
-- ===================================================================
\echo 'Testing sample query performance...'
\echo '======================================'

EXPLAIN ANALYZE
SELECT
    o.order_id, c.name, p.product_name, o.quantity, o.total_amount, o.order_status, o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products p ON o.product_id = p.product_id
WHERE o.order_status = 'DELIVERED'
AND o.order_date >= NOW() - INTERVAL '30 days'
ORDER BY o.order_date DESC
LIMIT 100;

\echo '======================================'
\echo 'Data generation completed successfully!'
\echo 'Database is ready for performance testing'
\echo '======================================'
