
/* ============================================================================
04_load_silver.sql
Silver load: Bronze -> Silver (cast + basic cleanup)
============================================================================ */

USE RetailSegmentation;
GO

-- Customers (dedupe by customer_id)
TRUNCATE TABLE silver.customers;

WITH d AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY (SELECT 1)) AS rn
  FROM bronze.olist_customers
)
INSERT INTO silver.customers
SELECT
  customer_id,
  customer_unique_id,
  TRY_CONVERT(INT, customer_zip_code_prefix),
  NULLIF(LTRIM(RTRIM(customer_city)), ''),
  NULLIF(LTRIM(RTRIM(customer_state)), '')
FROM d
WHERE rn = 1;

-- Sellers
TRUNCATE TABLE silver.sellers;

WITH d AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY (SELECT 1)) AS rn
  FROM bronze.olist_sellers
)
INSERT INTO silver.sellers
SELECT
  seller_id,
  TRY_CONVERT(INT, seller_zip_code_prefix),
  NULLIF(LTRIM(RTRIM(seller_city)), ''),
  NULLIF(LTRIM(RTRIM(seller_state)), '')
FROM d
WHERE rn = 1;

-- Products (note bronze column spelling "lenght")
TRUNCATE TABLE silver.products;

WITH d AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY (SELECT 1)) AS rn
  FROM bronze.olist_products
)
INSERT INTO silver.products
SELECT
  product_id,
  NULLIF(LTRIM(RTRIM(product_category_name)), ''),
  TRY_CONVERT(INT, product_name_lenght),
  TRY_CONVERT(INT, product_description_lenght),
  TRY_CONVERT(INT, product_photos_qty),
  TRY_CONVERT(INT, product_weight_g),
  TRY_CONVERT(INT, product_length_cm),
  TRY_CONVERT(INT, product_height_cm),
  TRY_CONVERT(INT, product_width_cm)
FROM d
WHERE rn = 1;

-- Category translation
TRUNCATE TABLE silver.category_translation;

WITH d AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY product_category_name ORDER BY (SELECT 1)) AS rn
  FROM bronze.product_category_name_translation
)
INSERT INTO silver.category_translation
SELECT
  NULLIF(LTRIM(RTRIM(product_category_name)), ''),
  NULLIF(LTRIM(RTRIM(product_category_name_english)), '')
FROM d
WHERE rn = 1
  AND NULLIF(LTRIM(RTRIM(product_category_name)), '') IS NOT NULL;

-- Orders
TRUNCATE TABLE silver.orders;

WITH d AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY (SELECT 1)) AS rn
  FROM bronze.olist_orders
)
INSERT INTO silver.orders
SELECT
  order_id,
  customer_id,
  NULLIF(LTRIM(RTRIM(order_status)), ''),
  TRY_CONVERT(DATETIME2(0), order_purchase_timestamp),
  TRY_CONVERT(DATETIME2(0), order_approved_at),
  TRY_CONVERT(DATETIME2(0), order_delivered_carrier_date),
  TRY_CONVERT(DATETIME2(0), order_delivered_customer_date),
  TRY_CONVERT(DATE, order_estimated_delivery_date)
FROM d
WHERE rn = 1;

-- Order items
TRUNCATE TABLE silver.order_items;

INSERT INTO silver.order_items
SELECT
  order_id,
  TRY_CONVERT(INT, order_item_id),
  product_id,
  seller_id,
  TRY_CONVERT(DATETIME2(0), shipping_limit_date),
  TRY_CONVERT(DECIMAL(18,2), price),
  TRY_CONVERT(DECIMAL(18,2), freight_value)
FROM bronze.olist_order_items
WHERE TRY_CONVERT(INT, order_item_id) IS NOT NULL;

-- Payments
TRUNCATE TABLE silver.order_payments;

INSERT INTO silver.order_payments
SELECT
  order_id,
  TRY_CONVERT(INT, payment_sequential),
  NULLIF(LTRIM(RTRIM(payment_type)), ''),
  TRY_CONVERT(INT, payment_installments),
  TRY_CONVERT(DECIMAL(18,2), payment_value)
FROM bronze.olist_order_payments
WHERE TRY_CONVERT(INT, payment_sequential) IS NOT NULL;

-- Reviews (dedupe by review_id)
TRUNCATE TABLE silver.order_reviews;

WITH d AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY review_id ORDER BY (SELECT 1)) AS rn
  FROM bronze.olist_order_reviews
)
INSERT INTO silver.order_reviews
SELECT
  review_id,
  order_id,
  TRY_CONVERT(TINYINT, review_score),
  NULLIF(LTRIM(RTRIM(review_comment_title)), ''),
  NULLIF(LTRIM(RTRIM(review_comment_message)), ''),
  TRY_CONVERT(DATETIME2(0), review_creation_date),
  TRY_CONVERT(DATETIME2(0), review_answer_timestamp)
FROM d
WHERE rn = 1;

-- Geolocation (no dedupe for now)
TRUNCATE TABLE silver.geolocation;

INSERT INTO silver.geolocation
SELECT
  TRY_CONVERT(INT, geolocation_zip_code_prefix),
  TRY_CONVERT(DECIMAL(10,7), geolocation_lat),
  TRY_CONVERT(DECIMAL(10,7), geolocation_lng),
  NULLIF(LTRIM(RTRIM(geolocation_city)), ''),
  NULLIF(LTRIM(RTRIM(geolocation_state)), '')
FROM bronze.olist_geolocation;
GO

/* Quick checks */
SELECT 'silver.customers' t, COUNT(*) c FROM silver.customers
UNION ALL SELECT 'silver.orders', COUNT(*) FROM silver.orders
UNION ALL SELECT 'silver.order_items', COUNT(*) FROM silver.order_items
UNION ALL SELECT 'silver.order_payments', COUNT(*) FROM silver.order_payments
UNION ALL SELECT 'silver.order_reviews', COUNT(*) FROM silver.order_reviews;
GO


