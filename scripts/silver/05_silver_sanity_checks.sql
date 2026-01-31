




/*----------------------------------------------------------

This script validates the Silver layer after loading from Bronze. Silver is where data becomes typed, cleaned, and joinable, so silent issues here will corrupt everything downstream (Gold modeling, segmentation, Power BI).

What it checks

Row counts: confirms expected volume landed in each Silver table.

Primary key integrity: ensures no duplicates exist where a unique grain is expected (customers, orders, products, order items).

Relationship integrity (orphans): detects broken joins (items without orders, orders without customers, payments/reviews without orders, items without products/sellers).

Missing critical fields: flags nulls in IDs, timestamps, and foreign keys that should rarely be missing.

Date logic: catches impossible timelines (approved before purchase, delivered before purchase, estimated delivery before purchase).

Numeric sanity: detects negative values and extreme outliers in prices, freight, and payments.

Domain checks: lists unexpected order_status values to catch inconsistent strings.

Cross-table reconciliation: compares total payments vs total items+freight to detect missing/incorrect data loads.

Reviews & geolocation validity: checks score distribution and invalid latitude/longitude ranges.

Expected outcomes

Duplicate counts should be 0.

Orphans and timeline violations should be 0 or very low (and explainable).

Outliers can exist, but should be reviewed before building Gold/BI.
-------------------------------------------------------------*/


/* ------------------------------------------------------------
1) Primary key integrity checks (should be 0 duplicates)
------------------------------------------------------------ */
-- customers duplicate customer_id
SELECT COUNT(*) AS dup_customers
FROM (
  SELECT customer_id
  FROM silver.customers
  GROUP BY customer_id
  HAVING COUNT(*) > 1
) d;

-- orders duplicate order_id
SELECT COUNT(*) AS dup_orders
FROM (
  SELECT order_id
  FROM silver.orders
  GROUP BY order_id
  HAVING COUNT(*) > 1
) d;

-- products duplicate product_id
SELECT COUNT(*) AS dup_products
FROM (
  SELECT product_id
  FROM silver.products
  GROUP BY product_id
  HAVING COUNT(*) > 1
) d;

-- order_items duplicate (order_id, order_item_id)
SELECT COUNT(*) AS dup_order_items
FROM (
  SELECT order_id, order_item_id
  FROM silver.order_items
  GROUP BY order_id, order_item_id
  HAVING COUNT(*) > 1
) d;
GO


/* ------------------------------------------------------------
2) Orphan checks (broken relationships)
These should be VERY low or explainable.
*/-- Order items without a matching order
------------------------------------------------------------ 
SELECT COUNT(*) AS orphan_order_items
FROM silver.order_items oi
LEFT JOIN silver.orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

-- Orders without a matching customer (customer_id present but not found)
SELECT COUNT(*) AS orphan_orders_customers
FROM silver.orders o
LEFT JOIN silver.customers c ON c.customer_id = o.customer_id
WHERE o.customer_id IS NOT NULL AND c.customer_id IS NULL;

-- Order items with missing product
SELECT COUNT(*) AS orphan_items_products
FROM silver.order_items oi
LEFT JOIN silver.products p ON p.product_id = oi.product_id
WHERE oi.product_id IS NOT NULL AND p.product_id IS NULL;

-- Order items with missing seller
SELECT COUNT(*) AS orphan_items_sellers
FROM silver.order_items oi
LEFT JOIN silver.sellers s ON s.seller_id = oi.seller_id
WHERE oi.seller_id IS NOT NULL AND s.seller_id IS NULL;

-- Payments without a matching order
SELECT COUNT(*) AS orphan_payments_orders
FROM silver.order_payments op
LEFT JOIN silver.orders o ON o.order_id = op.order_id
WHERE o.order_id IS NULL;

-- Reviews without a matching order
SELECT COUNT(*) AS orphan_reviews_orders
FROM silver.order_reviews r
LEFT JOIN silver.orders o ON o.order_id = r.order_id
WHERE r.order_id IS NOT NULL AND o.order_id IS NULL;
GO

/* ------------------------------------------------------------ 




3) Null / missing key fields (should be low)
------------------------------------------------------------ */
SELECT
  SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
  SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END) AS null_customer_unique_id,
  SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END) AS null_customer_state
FROM silver.customers;

SELECT
  SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
  SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_order_customer_id,
  SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_ts
FROM silver.orders;

SELECT
  SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_item_order_id,
  SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS null_item_id,
  SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
  SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS null_seller_id
FROM silver.order_items;

GO

/* ------------------------------------------------------------


4) Date logic checks (impossible timelines)
------------------------------------------------------------ */
-- approved before purchase
SELECT COUNT(*) AS approved_before_purchase
FROM silver.orders
WHERE order_approved_at IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_approved_at < order_purchase_timestamp;

-- delivered to customer before delivered to carrier (sometimes possible but usually suspicious)
SELECT COUNT(*) AS customer_delivered_before_carrier
FROM silver.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date < order_delivered_carrier_date;

-- delivered before purchase (should be 0)
SELECT COUNT(*) AS delivered_before_purchase
FROM silver.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp;

-- estimated delivery earlier than purchase (should be 0)
SELECT COUNT(*) AS estimated_before_purchase
FROM silver.orders
WHERE order_estimated_delivery_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_estimated_delivery_date < CAST(order_purchase_timestamp AS date)

GO



/* ------------------------------------------------------------


5) Numeric sanity checks (negative / absurd values)
------------------------------------------------------------ */
-- Negative or null monetary values in items
SELECT
  SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
  SUM(CASE WHEN price < 0 THEN 1 ELSE 0 END) AS negative_price,
  SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END) AS negative_freight
FROM silver.order_items;

-- Outlier checks (not “wrong”, but flags)
SELECT TOP 20
  order_id, order_item_id, price, freight_value
FROM silver.order_items
WHERE price > 5000 OR freight_value > 5000
ORDER BY price DESC, freight_value DESC;
GO

-- Payment value sanity
SELECT
  SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END) AS null_payment_value,
  SUM(CASE WHEN payment_value < 0 THEN 1 ELSE 0 END) AS negative_payment_value
FROM silver.order_payments;
GO

/* ------------------------------------------------------------
6) Status domain check (unexpected order_status values)
------------------------------------------------------------ */
SELECT order_status, COUNT(*) AS cnt
FROM silver.orders
GROUP BY order_status
ORDER BY cnt DESC;
GO
/* ------------------------------------------------------------

7) Cross-table reconciliation (items vs payments)
Not exact per order (multi-payments exist), but totals should be in same ballpark.
------------------------------------------------------------ */
-- Total of item prices + freight (approx order value proxy)
SELECT
  SUM(ISNULL(price,0) + ISNULL(freight_value,0)) AS total_items_plus_freight
FROM silver.order_items;

-- Total payments
SELECT
  SUM(ISNULL(payment_value,0)) AS total_payments
FROM silver.order_payments;
GO
/* ------------------------------------------------------------


8) Reviews sanity
------------------------------------------------------------ */
-- review_score distribution (should be 1..5 mostly)
SELECT review_score, COUNT(*) AS cnt
FROM silver.order_reviews
GROUP BY review_score
ORDER BY review_score;

-- Reviews with blank score
SELECT COUNT(*) AS null_review_score
FROM silver.order_reviews
WHERE review_score IS NULL;
GO

/* ------------------------------------------------------------


9) Geolocation sanity
------------------------------------------------------------ */
-- invalid lat/lng ranges (should be 0)
SELECT COUNT(*) AS invalid_lat_lng
FROM silver.geolocation
WHERE geolocation_lat IS NOT NULL AND (geolocation_lat < -90 OR geolocation_lat > 90)
   OR geolocation_lng IS NOT NULL AND (geolocation_lng < -180 OR geolocation_lng > 180);

-- zip prefix missing
SELECT COUNT(*) AS null_geo_zip_prefix
FROM silver.geolocation
WHERE geolocation_zip_code_prefix IS NULL;
GO
