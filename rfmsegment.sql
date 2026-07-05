-- ============================================================
-- MODULE 1: RFM CUSTOMER SEGMENTATION
-- ============================================================

-- STEP 1: Calculate raw RFM values per customer
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp)                    AS last_purchase_date,
        COUNT(DISTINCT o.order_id)                         AS frequency,
        SUM(p.payment_value)                               AS monetary,
        CURRENT_DATE - MAX(o.order_purchase_timestamp)::DATE AS recency_days
    FROM customers c
    JOIN orders o        ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id   = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

-- STEP 2: Score each customer 1-5 on R, F, M
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        ROUND(monetary::NUMERIC, 2)                        AS monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)         AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)             AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)              AS m_score
    FROM rfm_base
),

-- STEP 3: Combine scores into RFM segment
rfm_combined AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score)                      AS rfm_total,
        CONCAT(r_score, f_score, m_score)                  AS rfm_cell
    FROM rfm_scores
)

-- STEP 4: Label segments
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    rfm_total,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
        WHEN r_score >= 3 AND f_score <= 2 AND m_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Hibernating'
    END                                                     AS segment
FROM rfm_combined
ORDER BY rfm_total DESC;