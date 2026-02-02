
/* ============================================================================
08_customer_segmentation_snapshot.sql
Customer Segmentation (RFM) + segment labels
Grain: 1 row per customer (snapshot)
============================================================================ */

USE RetailSegmentation;
GO

IF OBJECT_ID('gold.customer_segmentation_snapshot','U') IS NOT NULL
    DROP TABLE gold.customer_segmentation_snapshot;
GO

CREATE TABLE gold.customer_segmentation_snapshot (
    snapshot_date      DATE          NOT NULL,
    customer_key       INT           NOT NULL,

    -- core metrics
    recency_days       INT           NULL,
    frequency_orders   INT           NULL,
    monetary_value     DECIMAL(18,2) NULL,
    aov                DECIMAL(18,2) NULL,

    -- scoring (1..5)
    r_score            TINYINT       NULL,
    f_score            TINYINT       NULL,
    m_score            TINYINT       NULL,
    rfm_code           INT           NULL,

    segment_name       NVARCHAR(50)  NULL,

    CONSTRAINT PK_customer_segmentation_snapshot
        PRIMARY KEY (snapshot_date, customer_key)
);
GO

DECLARE @as_of DATE;

SELECT @as_of = MAX(d.[date])
FROM gold.fact_orders fo
JOIN gold.dim_date d ON d.date_key = fo.purchase_date_key;

;WITH base AS (
    SELECT
        fo.customer_key,
        MAX(dd.[date]) AS last_purchase_date,
        COUNT(DISTINCT fo.order_id) AS frequency_orders,
        SUM(fp.payment_value) AS monetary_value
    FROM gold.fact_orders fo
    JOIN gold.dim_date dd
        ON dd.date_key = fo.purchase_date_key
    LEFT JOIN gold.fact_payments fp
        ON fp.order_id = fo.order_id
    WHERE fo.is_canceled = 0
      AND fo.purchase_date_key IS NOT NULL
    GROUP BY fo.customer_key
),
rfm AS (
    SELECT
        customer_key,
        DATEDIFF(DAY, last_purchase_date, @as_of) AS recency_days,
        frequency_orders,
        monetary_value,
        CASE WHEN frequency_orders > 0 THEN monetary_value / frequency_orders END AS aov
    FROM base
),
scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC)      AS r_score, -- lower recency is better
        NTILE(5) OVER (ORDER BY frequency_orders DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value DESC)   AS m_score
    FROM rfm
),
labeled AS (
    SELECT
        *,
        (r_score * 100) + (f_score * 10) + m_score AS rfm_code,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 4 AND f_score >= 3 THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Promising'
            WHEN r_score <= 2 AND (f_score >= 4 OR m_score >= 4) THEN 'At Risk'
            WHEN r_score = 1 AND f_score <= 2 THEN 'Lost'
            ELSE 'Needs Attention'
        END AS segment_name
    FROM scored
)
INSERT INTO gold.customer_segmentation_snapshot (
    snapshot_date, customer_key,
    recency_days, frequency_orders, monetary_value, aov,
    r_score, f_score, m_score, rfm_code,
    segment_name
)
SELECT
    @as_of, customer_key,
    recency_days, frequency_orders, monetary_value, aov,
    r_score, f_score, m_score, rfm_code,
    segment_name
FROM labeled;
GO

-- Quick distribution check
SELECT segment_name, COUNT(*) AS customers
FROM gold.customer_segmentation_snapshot
WHERE snapshot_date = CAST(GETDATE() AS DATE)
GROUP BY segment_name
ORDER BY customers DESC;
GO
