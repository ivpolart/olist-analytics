-- =============================================================
-- OLIST-1 · 02_data_quality.sql
-- Data overview: keys and joins, date range, order statuses,
-- missing dates, customer IDs.
-- Findings are summarized in notes.md.
-- =============================================================


-- =============================================================
-- 1. TABLES, KEYS AND JOINS
-- =============================================================

-- Columns that appear in more than one table = candidate join keys.
SELECT column_name,
       string_agg(table_name, ', ') AS tables
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY column_name
HAVING COUNT(*) > 1;


-- Primary key checks: an empty result means the column is unique.

-- products.product_id -> unique
SELECT product_id, COUNT(*)
FROM olist_products_dataset
GROUP BY product_id
HAVING COUNT(*) > 1;

-- customers.customer_id -> unique
SELECT customer_id, COUNT(*)
FROM olist_customers_dataset
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- orders.order_id -> unique
SELECT order_id, COUNT(*)
FROM olist_orders_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;

-- sellers.seller_id -> unique
SELECT seller_id, COUNT(*)
FROM olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- product_category_name_translation.product_category_name -> unique
SELECT product_category_name, COUNT(*)
FROM product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;


-- order_id is NOT unique in order_items, order_payments and order_reviews:
-- some orders have several rows there, so order_id is a foreign key.
SELECT order_id, COUNT(*)
FROM olist_order_items_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT order_id, COUNT(*)
FROM olist_order_payments_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT order_id, COUNT(*)
FROM olist_order_reviews_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;


-- Composite keys: empty result = the pair of columns is unique.

-- order_items: (order_id, order_item_id)
-- order_item_id is the item's position within the order (1, 2, 3...).
SELECT order_id, order_item_id, COUNT(*)
FROM olist_order_items_dataset
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- order_payments: (order_id, payment_sequential)
-- One order can be paid in several parts.
SELECT order_id, payment_sequential, COUNT(*)
FROM olist_order_payments_dataset
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;


-- review_id is NOT unique: the same review can be linked to several orders.
SELECT review_id, COUNT(*)
FROM olist_order_reviews_dataset
GROUP BY review_id
HAVING COUNT(*) > 1;


-- Join check: products whose category has no English translation.
-- Finding: some products have no category at all (NULL),
-- and some categories are missing from the translation table.
SELECT p.product_category_name,
       COUNT(*) AS products_count
FROM olist_products_dataset p
LEFT JOIN product_category_name_translation t
       ON t.product_category_name = p.product_category_name
WHERE t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY products_count DESC;


-- =============================================================
-- 2. DATE RANGE
-- Result: 2016-09-04 21:15:19 -> 2018-10-17 17:30:18
-- =============================================================
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM olist_orders_dataset;


-- =============================================================
-- 3. ORDER STATUSES
-- Result: delivered 96,478 · shipped 1,107 · canceled 625 ·
-- unavailable 609 · invoiced 314 · processing 301 ·
-- created 5 · approved 2 (total 99,441)
-- =============================================================
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY orders DESC;


-- =============================================================
-- 4. MISSING DATES
-- (run after 01_fix_types.sql, otherwise empty strings are not counted)
-- =============================================================

-- Overall: number of missing values in each date column.
-- Result: purchase 0 · approved 160 · carrier 1,783 ·
-- delivered to customer 2,965 · estimated 0
SELECT COUNT(*) - COUNT(order_purchase_timestamp)      AS missing_purchase,
       COUNT(*) - COUNT(order_approved_at)             AS missing_approved,
       COUNT(*) - COUNT(order_delivered_carrier_date)  AS missing_carrier,
       COUNT(*) - COUNT(order_delivered_customer_date) AS missing_delivered,
       COUNT(*) - COUNT(order_estimated_delivery_date) AS missing_estimated
FROM olist_orders_dataset;

-- By status: are the gaps expected or errors?
-- Finding:
--   - Gaps at intermediate stages (created, approved, invoiced,
--     processing, shipped) are expected: later stages have not happened yet.
--   - 75 canceled orders were already handed to the carrier (canceled in transit).
--   - Anomalies: 24 delivered orders with missing dates
--     (14 no approval, 2 no carrier date, 8 no delivery date)
--     and 6 canceled orders with a delivery date (possibly returns).
--     About 30 orders, < 0.03% of all orders.
SELECT order_status,
       COUNT(*) AS orders,
       COUNT(*) - COUNT(order_approved_at)             AS no_approved,
       COUNT(*) - COUNT(order_delivered_carrier_date)  AS no_carrier,
       COUNT(*) - COUNT(order_delivered_customer_date) AS no_delivered
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY orders DESC;


-- =============================================================
-- 5. customer_id vs customer_unique_id
-- Result: 99,441 customer_id vs 96,096 customer_unique_id.
-- A new customer_id is created for every order, so customers and
-- repeat purchases must be counted by customer_unique_id.
-- =============================================================
SELECT COUNT(DISTINCT customer_id)        AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS real_customers
FROM olist_customers_dataset;