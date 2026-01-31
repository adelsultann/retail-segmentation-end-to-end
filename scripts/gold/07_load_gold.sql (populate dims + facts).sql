/* ============================================================================
07_load_gold.sql
Loads Gold tables from Silver (dims first, then facts)
============================================================================ */

USE RetailSegmentation;
GO

/* -------------------------
1) CLEAR FACTS FIRST
--------------------------*/
TRUNCATE TABLE gold.fact_payments;
TRUNCATE TABLE gold.fact_order_items;
TRUNCATE TABLE gold.fact_orders;

/* -------------------------
2) REBUILD DIMENSIONS
--------------------------*/

/* DIM CUSTOMER */
DELETE FROM gold.dim_customer;
DBCC CHECKIDENT ('gold.dim_customer', RESEED, 0);


INSERT INTO gold.dim_customer (
    customer_id, customer_unique_id, customer_zip_code_prefix,
    customer_city, customer_state
)
SELECT
    customer_id, customer_unique_id, customer_zip_code_prefix,
    customer_city, customer_state
FROM silver.customers;

/* DIM SELLER */
DELETE FROM gold.dim_seller;
DBCC CHECKIDENT ('gold.dim_seller', RESEED, 0);

INSERT INTO gold.dim_seller (
    seller_id, seller_zip_code_prefix, seller_city, seller_state
)
SELECT
    seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM silver.sellers;

/* DIM PRODUCT */
DELETE FROM gold.dim_product;
DBCC CHECKIDENT ('gold.dim_product', RESEED, 0);

INSERT INTO gold.dim_product (
    product_id, product_category_name, product_category_english,
    product_weight_g, product_length_cm, product_height_cm, product_width_cm
)
SELECT
    p.product_id,
    p.product_category_name,
    ct.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM silver.products p
LEFT JOIN silver.category_translation ct
    ON ct.product_category_name = p.product_category_name;

/* -------------------------
3) DIM DATE
--------------------------*/

DECLARE @min_date DATE, @max_date DATE;

SELECT
    @min_date = MIN(CAST(order_purchase_timestamp AS DATE)),
    @max_date = MAX(CAST(order_purchase_timestamp AS DATE))
FROM silver.orders
WHERE order_purchase_timestamp IS NOT NULL;

IF @min_date IS NULL SET @min_date = '2016-01-01';
IF @max_date IS NULL SET @max_date = '2019-12-31';

DELETE FROM gold.dim_date;

;WITH d AS (
    SELECT @min_date AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt)
    FROM d
    WHERE dt < @max_date
)
INSERT INTO gold.dim_date (
    date_key, [date], [year], [quarter], [month], month_name,
    [day], day_of_week, day_name, is_weekend
)
SELECT
    (YEAR(dt) * 10000) + (MONTH(dt) * 100) + DAY(dt) AS date_key,
    dt,
    YEAR(dt),
    DATEPART(QUARTER, dt),
    MONTH(dt),
    DATENAME(MONTH, dt),
    DAY(dt),
    DATEPART(WEEKDAY, dt),
    DATENAME(WEEKDAY, dt),
    CASE WHEN DATENAME(WEEKDAY, dt) IN ('Saturday','Sunday') THEN 1 ELSE 0 END
FROM d
OPTION (MAXRECURSION 0);

/* -------------------------
4) FACT: ORDERS
--------------------------*/

INSERT INTO gold.fact_orders (
    order_id, customer_key,
    purchase_date_key, approved_date_key, delivered_customer_date_key, estimated_delivery_date_key,
    order_status, is_completed, is_canceled, delivery_days, approval_hours
)
SELECT
    o.order_id,
    dc.customer_key,

    CASE WHEN o.order_purchase_timestamp IS NULL
         THEN NULL ELSE (YEAR(o.order_purchase_timestamp)*10000 +
                         MONTH(o.order_purchase_timestamp)*100 +
                         DAY(o.order_purchase_timestamp)) END,

    CASE WHEN o.order_approved_at IS NULL
         THEN NULL ELSE (YEAR(o.order_approved_at)*10000 +
                         MONTH(o.order_approved_at)*100 +
                         DAY(o.order_approved_at)) END,

    CASE WHEN o.order_delivered_customer_date IS NULL
         THEN NULL ELSE (YEAR(o.order_delivered_customer_date)*10000 +
                         MONTH(o.order_delivered_customer_date)*100 +
                         DAY(o.order_delivered_customer_date)) END,

    CASE WHEN o.order_estimated_delivery_date IS NULL
         THEN NULL ELSE (YEAR(o.order_estimated_delivery_date)*10000 +
                         MONTH(o.order_estimated_delivery_date)*100 +
                         DAY(o.order_estimated_delivery_date)) END,

    o.order_status,
    CASE WHEN o.order_status = 'delivered' THEN 1 ELSE 0 END,
    CASE WHEN o.order_status IN ('canceled','unavailable') THEN 1 ELSE 0 END,

    CASE WHEN o.order_delivered_customer_date IS NOT NULL AND o.order_purchase_timestamp IS NOT NULL
         THEN DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)
         ELSE NULL END,

    CASE WHEN o.order_approved_at IS NOT NULL AND o.order_purchase_timestamp IS NOT NULL
         THEN DATEDIFF(HOUR, o.order_purchase_timestamp, o.order_approved_at)
         ELSE NULL END
FROM silver.orders o
LEFT JOIN gold.dim_customer dc ON dc.customer_id = o.customer_id;

/* -------------------------
5) FACT: ORDER ITEMS
--------------------------*/

INSERT INTO gold.fact_order_items (
    order_id, order_item_id, customer_key, product_key, seller_key, ship_limit_date_key,
    price, freight_value
)
SELECT
    oi.order_id,
    oi.order_item_id,
    dc.customer_key,
    dp.product_key,
    ds.seller_key,

    CASE WHEN oi.shipping_limit_date IS NULL
         THEN NULL ELSE (YEAR(oi.shipping_limit_date)*10000 +
                         MONTH(oi.shipping_limit_date)*100 +
                         DAY(oi.shipping_limit_date)) END,

    oi.price,
    oi.freight_value
FROM silver.order_items oi
LEFT JOIN silver.orders o ON o.order_id = oi.order_id
LEFT JOIN gold.dim_customer dc ON dc.customer_id = o.customer_id
LEFT JOIN gold.dim_product dp ON dp.product_id = oi.product_id
LEFT JOIN gold.dim_seller ds ON ds.seller_id = oi.seller_id;

/* -------------------------
6) FACT: PAYMENTS
--------------------------*/

INSERT INTO gold.fact_payments (
    order_id, payment_sequential, customer_key,
    payment_type, payment_installments, payment_value
)
SELECT
    p.order_id,
    p.payment_sequential,
    dc.customer_key,
    p.payment_type,
    p.payment_installments,
    p.payment_value
FROM silver.order_payments p
LEFT JOIN silver.orders o ON o.order_id = p.order_id
LEFT JOIN gold.dim_customer dc ON dc.customer_id = o.customer_id;
GO
