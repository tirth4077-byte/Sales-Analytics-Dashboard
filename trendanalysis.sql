-- ============================================================
-- MODULE 2: SALES TREND ANALYSIS
-- ============================================================

-- 2A: Monthly Revenue Trend
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)    AS month,
    COUNT(DISTINCT o.order_id)                         AS total_orders,
    SUM(p.payment_value)                               AS total_revenue,
    ROUND(AVG(p.payment_value)::NUMERIC, 2)            AS avg_order_value
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;


-- 2B: Revenue by State (Region)
SELECT
    c.customer_state                                   AS state,
    COUNT(DISTINCT o.order_id)                         AS total_orders,
    ROUND(SUM(p.payment_value)::NUMERIC, 2)            AS total_revenue,
    ROUND(AVG(p.payment_value)::NUMERIC, 2)            AS avg_order_value
FROM orders o
JOIN customers c      ON o.customer_id  = c.customer_id
JOIN order_payments p ON o.order_id     = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- 2C: Revenue by Product Category
SELECT
    COALESCE(pr.product_category_name, 'Unknown')      AS category,
    COUNT(DISTINCT o.order_id)                         AS total_orders,
    ROUND(SUM(oi.price)::NUMERIC, 2)                   AS total_revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2)                   AS avg_item_price
FROM orders o
JOIN order_items oi  ON o.order_id   = oi.order_id
JOIN products pr     ON oi.product_id = pr.product_id
WHERE o.order_status = 'delivered'
GROUP BY pr.product_category_name
ORDER BY total_revenue DESC
LIMIT 15;


-- 2D: Day of Week Sales Pattern
SELECT
    TO_CHAR(o.order_purchase_timestamp, 'Day')         AS day_of_week,
    EXTRACT(DOW FROM o.order_purchase_timestamp)       AS day_num,
    COUNT(DISTINCT o.order_id)                         AS total_orders,
    ROUND(SUM(p.payment_value)::NUMERIC, 2)            AS total_revenue
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY day_of_week, day_num
ORDER BY day_num;