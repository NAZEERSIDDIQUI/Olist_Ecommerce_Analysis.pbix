-- Olist Brazilian E-Commerce Analysis
-- PostgreSQL SQL Portfolio Project
-- Database: ecommerce_analysis

-- =========================================================
-- 1. DATA EXPLORATION
-- =========================================================

-- Row counts
SELECT 'orders' AS table_name, COUNT(*) AS rows FROM olist_orders_dataset
UNION ALL
SELECT 'customers', COUNT(*) FROM olist_customers_dataset
UNION ALL
SELECT 'order_items', COUNT(*) FROM olist_order_items_dataset
UNION ALL
SELECT 'payments', COUNT(*) FROM olist_order_payments_dataset
UNION ALL
SELECT 'reviews', COUNT(*) FROM olist_order_reviews_dataset
UNION ALL
SELECT 'products', COUNT(*) FROM olist_products_dataset
UNION ALL
SELECT 'sellers', COUNT(*) FROM olist_sellers_dataset;

-- Order status distribution
SELECT order_status, COUNT(*) AS order_count
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY order_count DESC;


-- =========================================================
-- 2. SALES ANALYSIS
-- =========================================================

-- Total payment revenue
SELECT ROUND(SUM(payment_value)::numeric, 2) AS total_revenue
FROM olist_order_payments_dataset;

-- Average order value
SELECT ROUND(
    SUM(payment_value)::numeric /
    COUNT(DISTINCT order_id), 2
) AS average_order_value
FROM olist_order_payments_dataset;

-- Revenue by payment type
SELECT
    payment_type,
    COUNT(*) AS payment_count,
    ROUND(SUM(payment_value)::numeric, 2) AS total_value
FROM olist_order_payments_dataset
GROUP BY payment_type
ORDER BY total_value DESC;

-- Monthly revenue
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    ROUND(SUM(p.payment_value)::numeric, 2) AS revenue
FROM olist_orders_dataset o
JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
GROUP BY month
ORDER BY month;

-- Revenue by customer state
SELECT
    c.customer_state,
    ROUND(SUM(p.payment_value)::numeric, 2) AS revenue
FROM olist_customers_dataset c
JOIN olist_orders_dataset o
    ON c.customer_id = o.customer_id
JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
GROUP BY c.customer_state
ORDER BY revenue DESC;


-- =========================================================
-- 3. CUSTOMER ANALYSIS
-- =========================================================

-- Total unique customers
SELECT COUNT(DISTINCT customer_unique_id) AS total_customers
FROM olist_customers_dataset;

-- Customers by state
SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS customers
FROM olist_customers_dataset
GROUP BY customer_state
ORDER BY customers DESC;

-- Repeat customers
SELECT
    customer_unique_id,
    COUNT(DISTINCT customer_id) AS customer_records
FROM olist_customers_dataset
GROUP BY customer_unique_id
HAVING COUNT(DISTINCT customer_id) > 1
ORDER BY customer_records DESC;


-- =========================================================
-- 4. PRODUCT ANALYSIS
-- =========================================================

-- Top product categories by sales value
SELECT
    p.product_category_name,
    ROUND(SUM(i.price)::numeric, 2) AS sales_value
FROM olist_order_items_dataset i
JOIN olist_products_dataset p
    ON i.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY sales_value DESC
LIMIT 10;

-- Top 10 products by sales value
SELECT
    i.product_id,
    ROUND(SUM(i.price)::numeric, 2) AS sales_value,
    COUNT(*) AS items_sold
FROM olist_order_items_dataset i
GROUP BY i.product_id
ORDER BY sales_value DESC
LIMIT 10;

-- Items sold by product category
SELECT
    p.product_category_name,
    COUNT(*) AS items_sold
FROM olist_order_items_dataset i
JOIN olist_products_dataset p
    ON i.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY items_sold DESC
LIMIT 10;


-- =========================================================
-- 5. SELLER ANALYSIS
-- =========================================================

-- Top 10 sellers by sales value
SELECT
    seller_id,
    ROUND(SUM(price)::numeric, 2) AS sales_value,
    COUNT(*) AS items_sold
FROM olist_order_items_dataset
GROUP BY seller_id
ORDER BY sales_value DESC
LIMIT 10;

-- Average freight cost
SELECT ROUND(AVG(freight_value)::numeric, 2) AS average_freight_cost
FROM olist_order_items_dataset;


-- =========================================================
-- 6. REVIEW ANALYSIS
-- =========================================================

-- Average review score
SELECT ROUND(AVG(review_score)::numeric, 2) AS average_review_score
FROM olist_order_reviews_dataset;

-- Review score distribution
SELECT
    review_score,
    COUNT(*) AS review_count
FROM olist_order_reviews_dataset
GROUP BY review_score
ORDER BY review_score;

-- Reviews by score
SELECT
    review_score,
    ROUND(AVG(review_comment_message IS NOT NULL)::numeric, 2) AS comment_presence_rate
FROM olist_order_reviews_dataset
GROUP BY review_score
ORDER BY review_score;


-- =========================================================
-- 7. DELIVERY PERFORMANCE
-- =========================================================

-- Average delivery time
SELECT ROUND(
    AVG(
        EXTRACT(
            DAY FROM (order_delivered_customer_date - order_purchase_timestamp)
        )
    )::numeric, 2
) AS average_delivery_days
FROM olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL;

-- Late vs on-time orders
SELECT
    CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 'Late'
        WHEN order_delivered_customer_date IS NOT NULL
            THEN 'On Time'
        ELSE 'Not Delivered'
    END AS delivery_status,
    COUNT(*) AS order_count
FROM olist_orders_dataset
GROUP BY delivery_status
ORDER BY order_count DESC;


-- =========================================================
-- 8. USEFUL PORTFOLIO VIEWS
-- =========================================================

-- Order summary
CREATE OR REPLACE VIEW order_summary AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND(COALESCE(SUM(p.payment_value), 0)::numeric, 2) AS order_value
FROM olist_orders_dataset o
LEFT JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
GROUP BY
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date;


-- Customer order summary
CREATE OR REPLACE VIEW customer_orders AS
SELECT
    c.customer_unique_id,
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COALESCE(SUM(p.payment_value), 0)::numeric, 2) AS total_spend
FROM olist_customers_dataset c
JOIN olist_orders_dataset o
    ON c.customer_id = o.customer_id
LEFT JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
GROUP BY
    c.customer_unique_id,
    c.customer_state;


-- Product sales summary
CREATE OR REPLACE VIEW product_sales AS
SELECT
    i.product_id,
    p.product_category_name,
    COUNT(*) AS items_sold,
    ROUND(SUM(i.price)::numeric, 2) AS sales_value,
    ROUND(AVG(i.price)::numeric, 2) AS average_item_price,
    ROUND(AVG(i.freight_value)::numeric, 2) AS average_freight
FROM olist_order_items_dataset i
JOIN olist_products_dataset p
    ON i.product_id = p.product_id
GROUP BY
    i.product_id,
    p.product_category_name;


-- State sales summary
CREATE OR REPLACE VIEW state_sales AS
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    ROUND(SUM(p.payment_value)::numeric, 2) AS total_revenue
FROM olist_customers_dataset c
JOIN olist_orders_dataset o
    ON c.customer_id = o.customer_id
JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
GROUP BY c.customer_state;


-- =========================================================
-- 9. FINAL BUSINESS INSIGHTS QUERIES
-- =========================================================

-- Top states by revenue
SELECT *
FROM state_sales
ORDER BY total_revenue DESC
LIMIT 10;

-- Top product categories
SELECT
    product_category_name,
    SUM(items_sold) AS items_sold,
    ROUND(SUM(sales_value)::numeric, 2) AS sales_value
FROM product_sales
GROUP BY product_category_name
ORDER BY sales_value DESC
LIMIT 10;

-- Top customers by spending
SELECT
    customer_unique_id,
    customer_state,
    total_orders,
    total_spend
FROM customer_orders
ORDER BY total_spend DESC
LIMIT 10;

-- Top sellers
SELECT
    seller_id,
    ROUND(SUM(price)::numeric, 2) AS sales_value,
    COUNT(*) AS items_sold
FROM olist_order_items_dataset
GROUP BY seller_id
ORDER BY sales_value DESC
LIMIT 10;
