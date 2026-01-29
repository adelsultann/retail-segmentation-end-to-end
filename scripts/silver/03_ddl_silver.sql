
/* ============================================================================
03_ddl_silver.sql
Silver layer: typed + cleaned tables (from bronze)
============================================================================ */

USE RetailSegmentation;
GO
CREATE SCHEMA silver;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO

/* -------------------------
   Customers
--------------------------*/
IF OBJECT_ID('silver.customers','U') IS NOT NULL DROP TABLE silver.customers;
GO

CREATE TABLE silver.customers (
    customer_id              CHAR(32)       NOT NULL,
    customer_unique_id       CHAR(32)       NULL,
    customer_zip_code_prefix INT           NULL,
    customer_city            NVARCHAR(200)  NULL,
    customer_state           CHAR(2)        NULL,
    CONSTRAINT PK_silver_customers PRIMARY KEY (customer_id)
);
GO

/* -------------------------
   Sellers
--------------------------*/
IF OBJECT_ID('silver.sellers','U') IS NOT NULL DROP TABLE silver.sellers;
GO

CREATE TABLE silver.sellers (
    seller_id                CHAR(32)       NOT NULL,
    seller_zip_code_prefix   INT            NULL,
    seller_city              NVARCHAR(200)  NULL,
    seller_state             CHAR(2)        NULL,
    CONSTRAINT PK_silver_sellers PRIMARY KEY (seller_id)
);
GO

/* -------------------------
   Products
--------------------------*/
IF OBJECT_ID('silver.products','U') IS NOT NULL DROP TABLE silver.products;
GO

CREATE TABLE silver.products (
    product_id                 CHAR(32)      NOT NULL,
    product_category_name      NVARCHAR(200) NULL,
    product_name_length        INT           NULL,
    product_description_length INT           NULL,
    product_photos_qty         INT           NULL,
    product_weight_g           INT           NULL,
    product_length_cm          INT           NULL,
    product_height_cm          INT           NULL,
    product_width_cm           INT           NULL,
    CONSTRAINT PK_silver_products PRIMARY KEY (product_id)
);
GO

/* -------------------------
   Category Translation
--------------------------*/
IF OBJECT_ID('silver.category_translation','U') IS NOT NULL DROP TABLE silver.category_translation;
GO

CREATE TABLE silver.category_translation (
    product_category_name         NVARCHAR(200) NOT NULL,
    product_category_name_english NVARCHAR(200) NULL,
    CONSTRAINT PK_silver_category_translation PRIMARY KEY (product_category_name)
);
GO

/* -------------------------
   Orders
--------------------------*/
IF OBJECT_ID('silver.orders','U') IS NOT NULL DROP TABLE silver.orders;
GO

CREATE TABLE silver.orders (
    order_id                      CHAR(32)       NOT NULL,
    customer_id                   CHAR(32)       NULL,
    order_status                  NVARCHAR(50)   NULL,
    order_purchase_timestamp      DATETIME2(0)   NULL,
    order_approved_at             DATETIME2(0)   NULL,
    order_delivered_carrier_date  DATETIME2(0)   NULL,
    order_delivered_customer_date DATETIME2(0)   NULL,
    order_estimated_delivery_date DATE           NULL,
    CONSTRAINT PK_silver_orders PRIMARY KEY (order_id)
);
GO

/* -------------------------
   Order Items
--------------------------*/
IF OBJECT_ID('silver.order_items','U') IS NOT NULL DROP TABLE silver.order_items;
GO

CREATE TABLE silver.order_items (
    order_id            CHAR(32)      NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          CHAR(32)       NULL,
    seller_id           CHAR(32)       NULL,
    shipping_limit_date DATETIME2(0)  NULL,
    price               DECIMAL(18,2) NULL,
    freight_value       DECIMAL(18,2) NULL,
    CONSTRAINT PK_silver_order_items PRIMARY KEY (order_id, order_item_id)
);
GO

/* -------------------------
   Payments
--------------------------*/
IF OBJECT_ID('silver.order_payments','U') IS NOT NULL DROP TABLE silver.order_payments;
GO

CREATE TABLE silver.order_payments (
    order_id             CHAR(32)      NOT NULL,
    payment_sequential   INT           NOT NULL,
    payment_type         NVARCHAR(50)  NULL,
    payment_installments INT           NULL,
    payment_value        DECIMAL(18,2) NULL,
    CONSTRAINT PK_silver_order_payments PRIMARY KEY (order_id, payment_sequential)
);
GO

/* -------------------------
   Reviews
--------------------------*/
IF OBJECT_ID('silver.order_reviews','U') IS NOT NULL DROP TABLE silver.order_reviews;
GO

CREATE TABLE silver.order_reviews (
    review_id              CHAR(32)       NOT NULL,
    order_id               CHAR(32)       NULL,
    review_score           TINYINT        NULL,
    review_comment_title   NVARCHAR(500)  NULL,
    review_comment_message NVARCHAR(2000) NULL,
    review_creation_date   DATETIME2(0)   NULL,
    review_answer_timestamp DATETIME2(0)  NULL,
    CONSTRAINT PK_silver_order_reviews PRIMARY KEY (review_id)
);
GO

/* -------------------------
   Geolocation
   (No PK: multiple rows per zip prefix exist)
--------------------------*/
IF OBJECT_ID('silver.geolocation','U') IS NOT NULL DROP TABLE silver.geolocation;
GO

CREATE TABLE silver.geolocation (
    geolocation_zip_code_prefix INT           NULL,
    geolocation_lat             DECIMAL(10,7) NULL,
    geolocation_lng             DECIMAL(10,7) NULL,
    geolocation_city            NVARCHAR(200) NULL,
    geolocation_state           CHAR(2)       NULL
);
GO
