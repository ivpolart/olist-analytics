# Working Notes: Olist Analysis

Short findings for each ticket: what I checked, what I found, and what I decided.
SQL queries live in the `sql/` folder; this file holds conclusions only.

---

## OLIST-1 · Data Overview and Data Quality

**Date:** 2026-10-08
**SQL:** `sql/01_fix_types.sql`, `sql/02_data_quality.sql`

### Tables and keys

| Table | Key | Joins to |
|---|---|---|
| orders | `order_id` | customers via `customer_id` |
| order_items | `order_id` + `order_item_id` | orders, products, sellers |
| order_payments | `order_id` + `payment_sequential` | orders |
| order_reviews | no unique key | orders via `order_id` |
| customers | `customer_id` | orders |
| products | `product_id` | order_items, category translation |
| sellers | `seller_id` | order_items |
| product_category_name_translation | `product_category_name` | products |

- `review_id` is not unique: the same review can be linked to several orders.
- Some products have no category, and some categories have no English translation.
- One order can contain several items and several payments. **Never join `order_items` and `order_payments` in one query without aggregating first**: rows multiply and totals get double-counted.

### Date range

- First order: 2016-09-04. Last order: 2018-10-17.
- The first and last months have very few orders; incomplete months must be cut off for trend analysis (to check in OLIST-2).

### Order statuses

| Status | Orders |
|---|---:|
| delivered | 96,478 |
| shipped | 1,107 |
| canceled | 625 |
| unavailable | 609 |
| invoiced | 314 |
| processing | 301 |
| created | 5 |
| approved | 2 |

### Missing dates

- After the import, dates were stored as text, and missing values were empty strings instead of NULL. Fixed the column types (`timestamp`, `numeric`) in `01_fix_types.sql`.
- Missing dates for orders at intermediate stages are expected: those stages have not happened yet.
- 75 canceled orders had already been handed to the carrier: canceled in transit, also expected.
- **Anomalies:** 24 delivered orders with missing dates and 6 canceled orders with a delivery date (possibly returns). About 30 orders in total, less than 0.03%.

### Customers

- 99,441 `customer_id` values, but only 96,096 real customers (`customer_unique_id`).
- A new `customer_id` is created for every order, so it cannot be used to count customers or repeat purchases.

### Decisions for further analysis

1. Count customers only by `customer_unique_id`.
2. Calculate revenue only from orders with status `delivered`.
3. Calculate delivery times only for `delivered` orders with all dates filled in.
4. Do not join `order_items` and `order_payments` directly: aggregate each to the order level first.

---

## OLIST-2 · Sales Trends

**Date:** 2026-10-12
**SQL:** `sql/03_sales_trends.sql`
**Stakeholder:** commercial director (preparing an investor presentation)

### Definitions agreed with the stakeholder

- Sales (revenue) = sum of item prices, without freight.
- Only delivered orders.
- An order belongs to the month of purchase.

### Findings

1. **Working period: January 2017 – August 2018** (20 full months). Sep–Dec 2016 is the platform launch (1, 265, 0 and 1 orders), and the data ends after August 2018.
2. **Year-over-year growth:** 21,998 orders in Jan–Aug 2017 vs 52,783 in Jan–Aug 2018, **x2.4**.
3. **But growth stopped in 2018:** orders plateau at about 6–7k per month and even slipped from 7,069 in January to 6,351 in August (about −10%).
4. **Average order value is stable at about 136** in both periods (change < 1%). Revenue grew only because the number of orders grew.
5. **November 2017 is a one-off spike:** revenue +52% vs October, then about −26% in December. The peak comes from a few days around _[fill in after step 6: date and number of orders]_.

### Lessons learned

- After a join, count orders with `COUNT(DISTINCT order_id)`, not `COUNT(*)`.
- AOV for a period = total revenue / total orders, not the average of monthly AOVs.
- Month-over-month % growth from a small base is misleading: check the absolute change too.

### Answer to the stakeholder (draft)

> Year over year we have 2.4 times more orders, but this growth happened in 2017. In 2018 orders are flat at 6–7k per month. Average order value is stable (~136), so revenue follows the number of orders. The best month is November 2017 (+52% vs October), driven by _[step 6 finding]_.
