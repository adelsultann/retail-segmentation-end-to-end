
/* ============================================================================
06_ddl_gold.sql
Gold layer: star schema (dims + facts) built from Silver
============================================================================ */

USE RetailSegmentation;
GO

/* -------------------------
   Ensure gold schema exists
--------------------------*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO

/* ============================================================================
   DROP TABLES IN DEPENDENCY ORDER (FACTS FIRST, THEN DIMENSIONS)
============================================================================ */

/* Facts */
IF OBJECT_ID('gold.fact_payments','U') IS NOT NULL
    DROP TABLE gold.fact_payments;
GO

IF OBJECT_ID('gold.fact_order_items','U') IS NOT NULL
    DROP TABLE gold.fact_order_items;
GO

IF OBJECT_ID('gold.fact_orders','U') IS NOT NULL
    DROP TABLE gold.fact_orders;
GO

/* Dimensions */
IF OBJECT_ID('gold.dim_product','U') IS NOT NULL
    DROP TABLE gold.dim_product;
GO

IF OBJECT_ID('gold.dim_seller','U') IS NOT NULL
    DROP TABLE gold.dim_seller;
GO

IF OBJECT_ID('gold.dim_customer','U') IS NOT NULL
    DROP TABLE gold.dim_customer;
GO

IF OBJECT_ID('gold.dim_date','U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO

/* ============================================================================
   CREATE DIMENSIONS
============================================================================ */

/* -------------------------
   DIM: Date
--------------------------*/
CREATE TABLE gold.dim_date (
    date_key      INT          NOT NULL,   -- YYYYMMDD
    [date]        DATE         NOT NULL,
    [year]        SMALLINT     NOT NULL,
    [quarter]     TINYINT      NOT NULL,
    [month]       TINYINT      NOT NULL,
    month_name    NVARCHAR(20) NOT NULL,
    [day]         TINYINT      NOT NULL,
    day_of_week   TINYINT      NOT NULL,   -- 1=Mon..7=Sun (depends on DATEFIRST)
    day_name      NVARCHAR(20) NOT NULL,
    is_weekend    BIT          NOT NULL,
    CONSTRAINT PK_dim_date PRIMARY KEY (date_key)
);
GO

/* -------------------------
   DIM: Customer
--------------------------*/
CREATE TABLE gold.dim_customer (
    customer_key             INT IDENTITY(1,1) NOT NULL,
    customer_id              CHAR(32)          NOT NULL,
    customer_unique_id       CHAR(32)          NULL,
    customer_zip_code_prefix INT               NULL,
    customer_city            NVARCHAR(200)     NULL,
    customer_state           CHAR(3)           NULL,
    CONSTRAINT PK_dim_customer PRIMARY KEY (customer_key),
    CONSTRAINT UQ_dim_customer_customer_id UNIQUE (customer_id)
);
GO

/* -------------------------
   DIM: Seller
--------------------------*/
CREATE TABLE gold.dim_seller (
    seller_key             INT IDENTITY(1,1) NOT NULL,
    seller_id              CHAR(32)          NOT NULL,
    seller_zip_code_prefix INT               NULL,
    seller_city            NVARCHAR(200)     NULL,
    seller_state           CHAR(2)           NULL,
    CONSTRAINT PK_dim_seller PRIMARY KEY (seller_key),
    CONSTRAINT UQ_dim_seller_seller_id UNIQUE (seller_id)
);
GO

/* -------------------------
   DIM: Product
--------------------------*/
CREATE TABLE gold.dim_product (
    product_key              INT IDENTITY(1,1) NOT NULL,
    product_id               CHAR(32)          NOT NULL,
    product_category_name    NVARCHAR(200)     NULL,
    product_category_english NVARCHAR(200)     NULL,
    product_weight_g         INT               NULL,
    product_length_cm        INT               NULL,
    product_height_cm        INT               NULL,
    product_width_cm         INT               NULL,
    CONSTRAINT PK_dim_product PRIMARY KEY (product_key),
    CONSTRAINT UQ_dim_product_product_id UNIQUE (product_id)
);
GO

/* ============================================================================
   CREATE FACTS
============================================================================ */

/* -------------------------
   FACT: Orders (order grain)
--------------------------*/
CREATE TABLE gold.fact_orders (
    order_id                    CHAR(32)      NOT NULL,
    customer_key                INT           NULL,
    purchase_date_key           INT           NULL,
    approved_date_key           INT           NULL,
    delivered_customer_date_key INT           NULL,
    estimated_delivery_date_key INT           NULL,
    order_status                NVARCHAR(50)  NULL,

    -- derived metrics
    is_completed                BIT           NOT NULL,
    is_canceled                 BIT           NOT NULL,
    delivery_days               INT           NULL,   -- delivered - purchase (days)
    approval_hours              INT           NULL,   -- approved - purchase (hours)

    CONSTRAINT PK_fact_orders PRIMARY KEY (order_id),
    CONSTRAINT FK_fact_orders_customer_key
        FOREIGN KEY (customer_key)
        REFERENCES gold.dim_customer(customer_key),
    CONSTRAINT FK_fact_orders_purchase_date
        FOREIGN KEY (purchase_date_key)
        REFERENCES gold.dim_date(date_key)
);
GO

/* -------------------------
   FACT: Order Items (line grain)
--------------------------*/
CREATE TABLE gold.fact_order_items (
    order_id            CHAR(32)      NOT NULL,
    order_item_id       INT           NOT NULL,
    customer_key        INT           NULL,
    product_key         INT           NULL,
    seller_key          INT           NULL,
    ship_limit_date_key INT           NULL,

    price               DECIMAL(18,2) NULL,
    freight_value       DECIMAL(18,2) NULL,
    line_total          AS (ISNULL(price,0) + ISNULL(freight_value,0)) PERSISTED,

    CONSTRAINT PK_fact_order_items PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT FK_foi_customer
        FOREIGN KEY (customer_key)
        REFERENCES gold.dim_customer(customer_key),
    CONSTRAINT FK_foi_product
        FOREIGN KEY (product_key)
        REFERENCES gold.dim_product(product_key),
    CONSTRAINT FK_foi_seller
        FOREIGN KEY (seller_key)
        REFERENCES gold.dim_seller(seller_key)
);
GO

/* -------------------------
   FACT: Payments
--------------------------*/
CREATE TABLE gold.fact_payments (
    order_id             CHAR(32)      NOT NULL,
    payment_sequential   INT           NOT NULL,
    customer_key         INT           NULL,
    payment_type         NVARCHAR(50)  NULL,
    payment_installments INT           NULL,
    payment_value        DECIMAL(18,2) NULL,
    CONSTRAINT PK_fact_payments PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT FK_fp_customer
        FOREIGN KEY (customer_key)
        REFERENCES gold.dim_customer(customer_key)
);
GO

/* ============================================================================
   Helpful indexes for BI
============================================================================ */
CREATE INDEX IX_fact_orders_customer_key
    ON gold.fact_orders(customer_key);

CREATE INDEX IX_fact_orders_purchase_date_key
    ON gold.fact_orders(purchase_date_key);

CREATE INDEX IX_fact_order_items_customer_key
    ON gold.fact_order_items(customer_key);

CREATE INDEX IX_fact_order_items_product_key
    ON gold.fact_order_items(product_key);
GO
