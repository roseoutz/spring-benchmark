-- Spring Boot Virtual Threads Performance Test Database Schema
-- 데이터베이스는 ENV 변수로 자동 생성됨

-- ===================================================================
-- 고객 테이블 (1M records)
-- ===================================================================
CREATE TABLE customers (
    customer_id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL
);

CREATE INDEX idx_customers_country ON customers(country);
CREATE INDEX idx_customers_email ON customers(email);

-- ===================================================================
-- 상품 테이블 (10K records)
-- ===================================================================
CREATE TABLE products (
    product_id BIGSERIAL PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price NUMERIC(12, 2) NOT NULL
);

CREATE INDEX idx_products_category ON products(category);

-- ===================================================================
-- 주문 테이블 (10M records)
-- ===================================================================
CREATE TABLE orders (
    order_id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_date TIMESTAMP NOT NULL DEFAULT NOW()
);

-- JOIN 성능을 위한 인덱스
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_product_id ON orders(product_id);

-- WHERE 필터링 및 ORDER BY를 위한 복합 인덱스
CREATE INDEX idx_orders_status_date ON orders(order_status, order_date DESC);

-- 외래 키 제약 조건 (옵션: 성능 고려하여 제외 가능)
-- 데이터 생성 속도를 위해 일단 주석 처리
-- ALTER TABLE orders ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id);
-- ALTER TABLE orders ADD CONSTRAINT fk_orders_product FOREIGN KEY (product_id) REFERENCES products(product_id);

-- 테이블 통계 출력 (디버깅용)
\echo 'Database schema initialized successfully'
\echo 'Tables: customers, products, orders'
\echo 'Ready for data seeding...'
