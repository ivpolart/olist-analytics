-- =============================================================
-- OLIST-2 · 03_sales_trends.sql
-- Sales trends by month for the commercial director.
--
-- Definitions agreed with the stakeholder:
--   * Sales (revenue) = sum of item prices (order_items.price), no freight.
--   * Only delivered orders (order_status = 'delivered').
--   * Orders are assigned to the month of purchase.
--   * Working period: 2017-01-01 to 2018-08-31 (20 full months).
-- Findings are summarized in notes.md.
-- =============================================================


-- -------------------------------------------------------------
-- Step 1. Delivered orders by month, full date range.
-- Finding: 2016-09, 2016-10 and 2016-12 are platform launch months
-- (1, 265 and 1 orders); 2016-11 has no orders at all (no row).
-- After 2018-08 there are no delivered orders: the data ends.
-- Decision: use January 2017 - August 2018.
-- -------------------------------------------------------------
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
       COUNT(*) AS orders
FROM olist_orders_dataset
WHERE order_status = 'delivered'
GROUP BY month
ORDER BY month;


-- -------------------------------------------------------------
-- Step 2. Year-over-year: Jan-Aug 2017 vs Jan-Aug 2018.
-- Result: 21,998 -> 52,783 orders, x2.40.
-- But within 2018 orders plateau at ~6-7k per month
-- (7,069 in January -> 6,351 in August).
-- -------------------------------------------------------------
WITH counts AS (
    SELECT
        (SELECT COUNT(*) FROM olist_orders_dataset
         WHERE order_status = 'delivered'
           AND order_purchase_timestamp >= '2017-01-01'
           AND order_purchase_timestamp <  '2017-09-01') AS c_2017,
        (SELECT COUNT(*) FROM olist_orders_dataset
         WHERE order_status = 'delivered'
           AND order_purchase_timestamp >= '2018-01-01'
           AND order_purchase_timestamp <  '2018-09-01') AS c_2018
)
SELECT c_2017 AS "2017",
       c_2018 AS "2018",
       ROUND(c_2018 * 1.0 / c_2017, 2) AS x_ratio
FROM counts;


-- -------------------------------------------------------------
-- Steps 3-4. Revenue, orders and average order value by month.
-- COUNT(DISTINCT order_id) is required: after the join an order
-- with several items has several rows.
-- Check: orders per month match step 1.
-- -------------------------------------------------------------
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
       SUM(price)                                         AS revenue,
       COUNT(DISTINCT ood.order_id)                       AS orders,
       ROUND(SUM(price) / COUNT(DISTINCT ood.order_id), 2) AS avg_check
FROM olist_orders_dataset ood
JOIN olist_order_items_dataset ooi ON ood.order_id = ooi.order_id
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY month
ORDER BY month;


-- -------------------------------------------------------------
-- Step 4b. Average order value for a whole period (no GROUP BY).
-- AOV for a period = total revenue / total orders,
-- NOT the average of monthly AOVs.
-- Result: ~136 in both Jan-Aug 2017 and Jan-Aug 2018 (< 1% change).
-- Revenue growth comes from the number of orders, not from AOV.
-- Change the dates to 2018-01-01 / 2018-09-01 for the second period.
-- -------------------------------------------------------------
SELECT SUM(price)                                          AS revenue,
       COUNT(DISTINCT ood.order_id)                        AS orders,
       ROUND(SUM(price) / COUNT(DISTINCT ood.order_id), 2) AS avg_check
FROM olist_orders_dataset ood
JOIN olist_order_items_dataset ooi ON ood.order_id = ooi.order_id
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2017-09-01';


-- -------------------------------------------------------------
-- Step 5. Month-over-month growth with LAG().
-- Finding: the largest % growth is in Feb-Mar 2017 (small base
-- during launch). November 2017 is the real anomaly: +52% revenue
-- vs October (+~340k) on a stable business, then about -26% in December.
-- -------------------------------------------------------------
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
           SUM(price)                   AS revenue,
           COUNT(DISTINCT ood.order_id) AS orders
    FROM olist_orders_dataset ood
    JOIN olist_order_items_dataset ooi ON ood.order_id = ooi.order_id
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
    GROUP BY month
)
SELECT month,
       revenue,
       orders,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
             / LAG(revenue) OVER (ORDER BY month), 1) AS revenue_growth_pct,
       ROUND((orders - LAG(orders) OVER (ORDER BY month)) * 100.0
             / LAG(orders) OVER (ORDER BY month), 1)  AS orders_growth_pct
FROM monthly
ORDER BY month;


-- -------------------------------------------------------------
-- Step 6. November 2017 by day: where does the peak come from?
-- Top 5 days by number of delivered orders.
-- Result: (fill in after running: date, weekday, orders)
-- -------------------------------------------------------------
SELECT order_purchase_timestamp::date               AS day,
       TO_CHAR(order_purchase_timestamp::date, 'Dy') AS weekday,
       COUNT(*)                                      AS orders
FROM olist_orders_dataset
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-11-01'
  AND order_purchase_timestamp <  '2017-12-01'
GROUP BY day, weekday
ORDER BY orders DESC
LIMIT 5;
