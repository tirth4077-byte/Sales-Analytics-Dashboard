-- ============================================================
-- MODULE 3: COHORT ANALYSIS (Customer Retention)
-- ============================================================

-- STEP 1: Find each customer's first purchase month (cohort)
WITH customer_cohort AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

-- STEP 2: Get all orders per customer with their cohort
customer_orders AS (
    SELECT
        c.customer_unique_id,
        cc.cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp)      AS order_month
    FROM customers c
    JOIN orders o        ON c.customer_id      = o.customer_id
    JOIN customer_cohort cc ON c.customer_unique_id = cc.customer_unique_id
    WHERE o.order_status = 'delivered'
),

-- STEP 3: Calculate how many months after cohort each order was placed
cohort_index AS (
    SELECT
        customer_unique_id,
        cohort_month,
        order_month,
        EXTRACT(YEAR FROM AGE(order_month, cohort_month)) * 12 +
        EXTRACT(MONTH FROM AGE(order_month, cohort_month)) AS month_number
    FROM customer_orders
),

-- STEP 4: Count unique customers per cohort per month_number
cohort_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_unique_id) AS customers
    FROM cohort_index
    GROUP BY cohort_month, month_number
),

-- STEP 5: Get cohort size (month 0 = first month)
cohort_size AS (
    SELECT
        cohort_month,
        customers AS cohort_total
    FROM cohort_counts
    WHERE month_number = 0
)

-- STEP 6: Calculate retention rate
SELECT
    TO_CHAR(cc.cohort_month, 'YYYY-MM')                     AS cohort,
    cc.month_number,
    cc.customers,
    cs.cohort_total,
    ROUND(100.0 * cc.customers / cs.cohort_total, 2)        AS retention_rate_pct
FROM cohort_counts cc
JOIN cohort_size cs ON cc.cohort_month = cs.cohort_month
WHERE cc.cohort_month >= '2017-01-01'
  AND cc.month_number <= 12
ORDER BY cc.cohort_month, cc.month_number;