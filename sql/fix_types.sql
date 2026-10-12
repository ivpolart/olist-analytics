-- =============================================================
-- OLIST-1 · 01_fix_types.sql
-- Fix column types after CSV import.
--
-- Problem: after the import, dates and money columns were stored
-- as text, and missing values were empty strings ('') instead of NULL.
-- As a result, COUNT() treated empty values as filled in, and date
-- arithmetic (delivery times) was impossible.
--
-- Fix: convert dates to timestamp and money to numeric(10,2).
-- NULLIF(TRIM(...), '') turns empty strings and spaces into NULL.
-- ::text makes the script safe to run on any source type.
-- =============================================================


-- -------------------------------------------------------------
-- orders: all five date columns
-- -------------------------------------------------------------
ALTER TABLE olist_orders_dataset
  ALTER COLUMN order_purchase_timestamp      TYPE timestamp USING NULLIF(TRIM(order_purchase_timestamp::text), '')::timestamp,
  ALTER COLUMN order_approved_at             TYPE timestamp USING NULLIF(TRIM(order_approved_at::text), '')::timestamp,
  ALTER COLUMN order_delivered_carrier_date  TYPE timestamp USING NULLIF(TRIM(order_delivered_carrier_date::text), '')::timestamp,
  ALTER COLUMN order_delivered_customer_date TYPE timestamp USING NULLIF(TRIM(order_delivered_customer_date::text), '')::timestamp,
  ALTER COLUMN order_estimated_delivery_date TYPE timestamp USING NULLIF(TRIM(order_estimated_delivery_date::text), '')::timestamp;


-- -------------------------------------------------------------
-- order_items: price, freight and shipping deadline
-- -------------------------------------------------------------
ALTER TABLE olist_order_items_dataset
  ALTER COLUMN price               TYPE numeric(10,2) USING NULLIF(TRIM(price::text), '')::numeric,
  ALTER COLUMN freight_value       TYPE numeric(10,2) USING NULLIF(TRIM(freight_value::text), '')::numeric,
  ALTER COLUMN shipping_limit_date TYPE timestamp     USING NULLIF(TRIM(shipping_limit_date::text), '')::timestamp;


-- -------------------------------------------------------------
-- order_payments: payment amount
-- -------------------------------------------------------------
ALTER TABLE olist_order_payments_dataset
  ALTER COLUMN payment_value TYPE numeric(10,2) USING NULLIF(TRIM(payment_value::text), '')::numeric;


-- -------------------------------------------------------------
-- Check: dates should be "timestamp without time zone",
-- money columns should be "numeric".
-- -------------------------------------------------------------
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE column_name IN ('price', 'freight_value', 'shipping_limit_date', 'payment_value',
                      'order_purchase_timestamp', 'order_approved_at',
                      'order_delivered_carrier_date', 'order_delivered_customer_date',
                      'order_estimated_delivery_date')
ORDER BY table_name, column_name;