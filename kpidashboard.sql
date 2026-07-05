-- ============================================================
-- MODULE 4: KPI DASHBOARD VIEWS (Power BI connects to these)
-- ============================================================

-- VIEW 1: Monthly KPI Summary
CREATE OR REPLACE VIEW vw_monthly_kpi AS
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)        AS month,
    COUNT(DISTINCT o.order_id)                             AS total_orders,
    COUNT(DISTINCT c.customer_unique_id)                   AS unique_customers,
    ROUND(SUM(p.payment_value)::NUMERIC, 2)                AS total_revenue,
    ROUND(AVG(p.payment_value)::NUMERIC, 2)                AS avg_order_value,
    ROUND(SUM(oi.freight_value)::NUMERIC, 2)               AS total_freight,
    ROUND(AVG(r.review_score)::NUMERIC, 2)                 AS avg_review_score
FROM orders o
JOIN customers c       ON o.customer_id  = c.customer_id
JOIN order_payments p  ON o.order_id     = p.order_id
JOIN order_items oi    ON o.order_id     = oi.order_id
JOIN order_reviews r   ON o.order_id     = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;


-- VIEW 2: RFM Segments Summary (for Power BI pie/bar chart)
CREATE OR REPLACE VIEW vw_rfm_segments AS
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        CURRENT_DATE - MAX(o.order_purchase_timestamp)::DATE AS recency_days,
        COUNT(DISTINCT o.order_id)                           AS frequency,
        SUM(p.payment_value)                                 AS monetary
    FROM customers c
    JOIN orders o        ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id   = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        ROUND(monetary::NUMERIC, 2)                          AS monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)           AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)               AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)                AS m_score
    FROM rfm_base
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
        WHEN r_score >= 3 AND f_score <= 2 AND m_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Hibernating'
    END                                                      AS segment
FROM rfm_scores;


-- VIEW 3: Sales by Region & Category
CREATE OR REPLACE VIEW vw_sales_by_region_category AS
SELECT
    c.customer_state                                        AS state,
    COALESCE(pr.product_category_name, 'Unknown')           AS category,
    COUNT(DISTINCT o.order_id)                              AS total_orders,
    ROUND(SUM(p.payment_value)::NUMERIC, 2)                 AS total_revenue,
    ROUND(AVG(p.payment_value)::NUMERIC, 2)                 AS avg_order_value,
    ROUND(AVG(r.review_score)::NUMERIC, 2)                  AS avg_review_score
FROM orders o
JOIN customers c       ON o.customer_id   = c.customer_id
JOIN order_payments p  ON o.order_id      = p.order_id
JOIN order_items oi    ON o.order_id      = oi.order_id
JOIN products pr       ON oi.product_id   = pr.product_id
JOIN order_reviews r   ON o.order_id      = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state, pr.product_category_name
ORDER BY total_revenue DESC;


-- VIEW 4: Cohort Retention
CREATE OR REPLACE VIEW vw_cohort_retention AS
WITH customer_cohort AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_orders AS (
    SELECT
        c.customer_unique_id,
        cc.cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp)      AS order_month
    FROM customers c
    JOIN orders o          ON c.customer_id        = o.customer_id
    JOIN customer_cohort cc ON c.customer_unique_id = cc.customer_unique_id
    WHERE o.order_status = 'delivered'
),
cohort_index AS (
    SELECT
        customer_unique_id,
        cohort_month,
        order_month,
        EXTRACT(YEAR  FROM AGE(order_month, cohort_month)) * 12 +
        EXTRACT(MONTH FROM AGE(order_month, cohort_month))   AS month_number
    FROM customer_orders
),
cohort_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_unique_id)                   AS customers
    FROM cohort_index
    GROUP BY cohort_month, month_number
),
cohort_size AS (
    SELECT cohort_month, customers AS cohort_total
    FROM cohort_counts
    WHERE month_number = 0
)
SELECT
    TO_CHAR(cc.cohort_month, 'YYYY-MM')                     AS cohort,
    cc.month_number,
    cc.customers,
    cs.cohort_total,
    ROUND(100.0 * cc.customers / cs.cohort_total, 2)         AS retention_rate_pct
FROM cohort_counts cc
JOIN cohort_size cs ON cc.cohort_month = cs.cohort_month
WHERE cc.cohort_month >= '2017-01-01'
  AND cc.month_number <= 12
ORDER BY cc.cohort_month, cc.month_number;


-- Verify all 4 views created
SELECT table_name
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;