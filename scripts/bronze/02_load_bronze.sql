
/* ============================================================================
02_load_bronze.sql
Loads CSV files into bronze tables using BULK INSERT (SQL Server 2017+)
Path: C:\Users\adela\Downloads\Customer Segmentation\DataSet
============================================================================ */

USE RetailSegmentation;
GO

-- If your SQL Server complains, run in SQLCMD mode and use:
-- :setvar DataPath "C:\Users\adela\Downloads\Customer Segmentation\DataSet\"
-- Then replace the hardcoded path with $(DataPath)

-- Optional: clear tables before reload (safe for bronze)
TRUNCATE TABLE bronze.olist_customers;
TRUNCATE TABLE bronze.olist_sellers;
TRUNCATE TABLE bronze.olist_products;
TRUNCATE TABLE bronze.product_category_name_translation;
TRUNCATE TABLE bronze.olist_orders;
TRUNCATE TABLE bronze.olist_order_items;
TRUNCATE TABLE bronze.olist_order_payments;
TRUNCATE TABLE bronze.olist_order_reviews;
TRUNCATE TABLE bronze.olist_geolocation;
GO

/* =========================
   olist_customers_dataset.csv
========================= */
BULK INSERT bronze.olist_customers
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\olist_customers_dataset.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/* =========================
   olist_sellers_dataset.csv
========================= */
BULK INSERT bronze.olist_sellers
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\olist_sellers_dataset.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/* =========================
   olist_products_dataset.csv
========================= */
BULK INSERT bronze.olist_products
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\olist_products_dataset.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/* =========================
   product_category_name_translation.csv
========================= */
BULK INSERT bronze.product_category_name_translation
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\product_category_name_translation.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/* =========================
   olist_orders_dataset.csv
========================= */
BULK INSERT bronze.olist_orders
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\olist_orders_dataset.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/* =========================
   olist_order_items_dataset.csv
========================= */
BULK INSERT bronze.olist_order_items
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\olist_order_items_dataset.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/* =========================
   olist_order_payments_dataset.csv
========================= */
BULK INSERT bronze.olist_order_payments
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\olist_order_payments_dataset.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/* =========================
   olist_order_reviews_dataset.csv
========================= */
BULK INSERT bronze.olist_order_reviews
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\olist_order_reviews_dataset.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0d0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO
/* =========================
   olist_geolocation_dataset.csv
========================= */
BULK INSERT bronze.olist_geolocation
FROM 'C:\Users\adela\Downloads\Customer Segmentation\DataSet\olist_geolocation_dataset.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/* =========================
   Quick sanity checks
========================= */
SELECT 'olist_customers' AS table_name, COUNT(*) AS row_count FROM bronze.olist_customers
UNION ALL SELECT 'olist_sellers', COUNT(*) FROM bronze.olist_sellers
UNION ALL SELECT 'olist_products', COUNT(*) FROM bronze.olist_products
UNION ALL SELECT 'product_category_name_translation', COUNT(*) FROM bronze.product_category_name_translation
UNION ALL SELECT 'olist_orders', COUNT(*) FROM bronze.olist_orders
UNION ALL SELECT 'olist_order_items', COUNT(*) FROM bronze.olist_order_items
UNION ALL SELECT 'olist_order_payments', COUNT(*) FROM bronze.olist_order_payments
UNION ALL SELECT 'olist_order_reviews', COUNT(*) FROM bronze.olist_order_reviews
UNION ALL SELECT 'olist_geolocation', COUNT(*) FROM bronze.olist_geolocation;
GO
