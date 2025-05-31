-- =================================================================
-- 最終面接用 総合SQLスクリプト集
-- 基本的なCOUNTから始まり、実践的なビジネスシナリオまでカバー
-- =================================================================

-- =================================================================
-- 1. 基本統計とデータ品質チェック
-- =================================================================

-- 元のクエリ：顧客数の単純カウント
SELECT COUNT(*) AS customer_count FROM customers;

-- より詳細な顧客統計
SELECT 
    COUNT(*) AS total_customers,
    COUNT(DISTINCT email) AS unique_emails,
    COUNT(*) - COUNT(email) AS customers_without_email,
    COUNT(CASE WHEN created_at >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) AS new_customers_last_30_days,
    COUNT(CASE WHEN last_login_date >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) AS active_customers_last_30_days,
    ROUND(AVG(EXTRACT(YEAR FROM age(birth_date))), 2) AS avg_customer_age
FROM customers;

-- データ品質チェック：重複データの検出
WITH duplicate_check AS (
    SELECT 
        email,
        COUNT(*) as duplicate_count,
        STRING_AGG(customer_id::text, ', ') as customer_ids
    FROM customers 
    WHERE email IS NOT NULL
    GROUP BY email
    HAVING COUNT(*) > 1
)
SELECT 
    'Duplicate Emails Found' as issue_type,
    COUNT(*) as total_duplicates,
    SUM(duplicate_count) as total_affected_records
FROM duplicate_check;

-- =================================================================
-- 2. 顧客セグメンテーション分析
-- =================================================================

-- RFM分析（Recency, Frequency, Monetary）
WITH customer_rfm AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        EXTRACT(DAYS FROM CURRENT_DATE - MAX(o.order_date)) as recency_days,
        COUNT(DISTINCT o.order_id) as frequency,
        COALESCE(SUM(o.total_amount), 0) as monetary_value
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE c.created_at <= CURRENT_DATE - INTERVAL '90 days' -- 最低90日の履歴がある顧客
    GROUP BY c.customer_id, c.first_name, c.last_name
),
rfm_scores AS (
    SELECT *,
        CASE 
            WHEN recency_days <= 30 THEN 5
            WHEN recency_days <= 60 THEN 4
            WHEN recency_days <= 90 THEN 3
            WHEN recency_days <= 180 THEN 2
            ELSE 1
        END as recency_score,
        CASE 
            WHEN frequency >= 10 THEN 5
            WHEN frequency >= 5 THEN 4
            WHEN frequency >= 3 THEN 3
            WHEN frequency >= 1 THEN 2
            ELSE 1
        END as frequency_score,
        CASE 
            WHEN monetary_value >= 1000 THEN 5
            WHEN monetary_value >= 500 THEN 4
            WHEN monetary_value >= 200 THEN 3
            WHEN monetary_value >= 50 THEN 2
            ELSE 1
        END as monetary_score
    FROM customer_rfm
)
SELECT 
    CASE 
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
        WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
        WHEN recency_score <= 2 AND frequency_score >= 3 THEN 'At Risk'
        WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'Lost Customers'
        ELSE 'Regular Customers'
    END as customer_segment,
    COUNT(*) as customer_count,
    ROUND(AVG(monetary_value), 2) as avg_monetary_value,
    ROUND(AVG(frequency), 2) as avg_frequency,
    ROUND(AVG(recency_days), 2) as avg_recency_days
FROM rfm_scores
GROUP BY customer_segment
ORDER BY customer_count DESC;

-- =================================================================
-- 3. 売上分析とトレンド
-- =================================================================

-- 月次売上トレンドと前年同月比較
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', order_date) as sales_month,
        COUNT(DISTINCT order_id) as total_orders,
        COUNT(DISTINCT customer_id) as unique_customers,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_order_value
    FROM orders 
    WHERE order_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY DATE_TRUNC('month', order_date)
),
sales_with_comparison AS (
    SELECT *,
        LAG(total_revenue, 12) OVER (ORDER BY sales_month) as revenue_same_month_last_year,
        LAG(total_revenue, 1) OVER (ORDER BY sales_month) as revenue_previous_month
    FROM monthly_sales
)
SELECT 
    TO_CHAR(sales_month, 'YYYY-MM') as month,
    total_orders,
    unique_customers,
    ROUND(total_revenue, 2) as revenue,
    ROUND(avg_order_value, 2) as aov,
    CASE 
        WHEN revenue_same_month_last_year IS NOT NULL 
        THEN ROUND(((total_revenue - revenue_same_month_last_year) / revenue_same_month_last_year * 100), 2)
        ELSE NULL 
    END as yoy_growth_percent,
    CASE 
        WHEN revenue_previous_month IS NOT NULL 
        THEN ROUND(((total_revenue - revenue_previous_month) / revenue_previous_month * 100), 2)
        ELSE NULL 
    END as mom_growth_percent
FROM sales_with_comparison
ORDER BY sales_month DESC
LIMIT 12;

-- =================================================================
-- 4. 製品パフォーマンス分析
-- =================================================================

-- 製品別売上ランキング（ABC分析）
WITH product_sales AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.quantity) as total_quantity_sold,
        SUM(oi.quantity * oi.unit_price) as total_revenue,
        COUNT(DISTINCT oi.order_id) as total_orders,
        AVG(oi.unit_price) as avg_selling_price
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY p.product_id, p.product_name, p.category
),
product_ranking AS (
    SELECT *,
        SUM(total_revenue) OVER () as grand_total_revenue,
        ROUND((total_revenue / SUM(total_revenue) OVER () * 100), 2) as revenue_percentage,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC 
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as cumulative_revenue
    FROM product_sales
),
abc_classification AS (
    SELECT *,
        ROUND((cumulative_revenue / grand_total_revenue * 100), 2) as cumulative_percentage,
        CASE 
            WHEN (cumulative_revenue / grand_total_revenue * 100) <= 80 THEN 'A'
            WHEN (cumulative_revenue / grand_total_revenue * 100) <= 95 THEN 'B'
            ELSE 'C'
        END as abc_class
    FROM product_ranking
)
SELECT 
    abc_class,
    COUNT(*) as product_count,
    SUM(total_revenue) as class_revenue,
    ROUND(AVG(revenue_percentage), 2) as avg_revenue_percentage,
    STRING_AGG(product_name, ', ' ORDER BY total_revenue DESC) as top_products
FROM abc_classification
GROUP BY abc_class
ORDER BY abc_class;

-- =================================================================
-- 5. コホート分析（顧客定着率）
-- =================================================================

WITH customer_cohorts AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_date)) as cohort_month
    FROM orders
    GROUP BY customer_id
),
customer_activities AS (
    SELECT 
        cc.customer_id,
        cc.cohort_month,
        DATE_TRUNC('month', o.order_date) as activity_month,
        EXTRACT(YEAR FROM AGE(o.order_date, cc.cohort_month)) * 12 + 
        EXTRACT(MONTH FROM AGE(o.order_date, cc.cohort_month)) as period_number
    FROM customer_cohorts cc
    JOIN orders o ON cc.customer_id = o.customer_id
),
cohort_table AS (
    SELECT 
        cohort_month,
        period_number,
        COUNT(DISTINCT customer_id) as customers
    FROM customer_activities
    GROUP BY cohort_month, period_number
),
cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) as cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
)
SELECT 
    TO_CHAR(ct.cohort_month, 'YYYY-MM') as cohort,
    cs.cohort_size,
    ct.period_number,
    ct.customers,
    ROUND((ct.customers::float / cs.cohort_size * 100), 2) as retention_rate
FROM cohort_table ct
JOIN cohort_sizes cs ON ct.cohort_month = cs.cohort_month
WHERE ct.cohort_month >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY ct.cohort_month, ct.period_number;

-- =================================================================
-- 6. 高度な分析クエリ
-- =================================================================

-- 顧客の購買行動パターン分析
WITH customer_purchase_patterns AS (
    SELECT 
        c.customer_id,
        COUNT(DISTINCT o.order_id) as total_orders,
        AVG(EXTRACT(DAYS FROM o.order_date - LAG(o.order_date) 
            OVER (PARTITION BY c.customer_id ORDER BY o.order_date))) as avg_days_between_orders,
        STDDEV(o.total_amount) as order_amount_stddev,
        COUNT(DISTINCT DATE_TRUNC('hour', o.created_at)) as unique_order_hours,
        MODE() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM o.created_at)) as preferred_order_hour,
        COUNT(DISTINCT EXTRACT(DOW FROM o.order_date)) as days_of_week_variety
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY c.customer_id
    HAVING COUNT(DISTINCT o.order_id) >= 3
)
SELECT 
    CASE 
        WHEN avg_days_between_orders <= 7 THEN 'Frequent (Weekly)'
        WHEN avg_days_between_orders <= 30 THEN 'Regular (Monthly)'
        WHEN avg_days_between_orders <= 90 THEN 'Occasional (Quarterly)'
        ELSE 'Rare (Seasonal)'
    END as purchase_frequency_pattern,
    COUNT(*) as customer_count,
    ROUND(AVG(avg_days_between_orders), 1) as avg_interval_days,
    ROUND(AVG(order_amount_stddev), 2) as avg_spending_consistency
FROM customer_purchase_patterns
WHERE avg_days_between_orders IS NOT NULL
GROUP BY purchase_frequency_pattern
ORDER BY customer_count DESC;

-- =================================================================
-- 7. パフォーマンス最適化とインデックス提案
-- =================================================================

-- 遅いクエリの特定（実行計画分析用）
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(o.order_id) as order_count,
    SUM(o.total_amount) as total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.created_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(o.order_id) > 0
ORDER BY total_spent DESC;

-- インデックス作成提案
-- CREATE INDEX CONCURRENTLY idx_customers_created_at ON customers(created_at) WHERE created_at >= CURRENT_DATE - INTERVAL '2 years';
-- CREATE INDEX CONCURRENTLY idx_orders_customer_date ON orders(customer_id, order_date DESC);
-- CREATE INDEX CONCURRENTLY idx_order_items_product ON order_items(product_id, quantity, unit_price);

-- =================================================================
-- 8. データウェアハウス用集約テーブル
-- =================================================================

-- 日次売上サマリ（マテリアライズドビュー候補）
CREATE OR REPLACE VIEW daily_sales_summary AS
WITH daily_metrics AS (
    SELECT 
        DATE(order_date) as sales_date,
        COUNT(DISTINCT order_id) as total_orders,
        COUNT(DISTINCT customer_id) as unique_customers,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_order_value,
        MAX(total_amount) as max_order_value,
        MIN(total_amount) as min_order_value,
        COUNT(DISTINCT CASE WHEN total_amount > 100 THEN customer_id END) as high_value_customers
    FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY DATE(order_date)
)
SELECT 
    sales_date,
    total_orders,
    unique_customers,
    ROUND(total_revenue, 2) as total_revenue,
    ROUND(avg_order_value, 2) as avg_order_value,
    max_order_value,
    min_order_value,
    high_value_customers,
    ROUND((unique_customers::float / total_orders * 100), 2) as customer_order_ratio,
    total_revenue - LAG(total_revenue) OVER (ORDER BY sales_date) as revenue_change_from_previous_day
FROM daily_metrics
ORDER BY sales_date DESC;

-- =================================================================
-- 9. ストアドプロシージャ例
-- =================================================================

-- 顧客ライフタイムバリュー計算
CREATE OR REPLACE FUNCTION calculate_customer_ltv(
    p_customer_id INTEGER,
    p_prediction_months INTEGER DEFAULT 12
) RETURNS TABLE (
    customer_id INTEGER,
    current_ltv DECIMAL(10,2),
    predicted_ltv DECIMAL(10,2),
    avg_monthly_value DECIMAL(10,2),
    months_active INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH customer_metrics AS (
        SELECT 
            c.customer_id,
            EXTRACT(MONTHS FROM AGE(CURRENT_DATE, MIN(o.order_date))) as months_active,
            COUNT(DISTINCT o.order_id) as total_orders,
            SUM(o.total_amount) as total_spent,
            AVG(o.total_amount) as avg_order_value
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        WHERE c.customer_id = p_customer_id
        GROUP BY c.customer_id
    )
    SELECT 
        cm.customer_id,
        ROUND(cm.total_spent, 2)::DECIMAL(10,2),
        ROUND((cm.total_spent / GREATEST(cm.months_active, 1)) * p_prediction_months, 2)::DECIMAL(10,2),
        ROUND(cm.total_spent / GREATEST(cm.months_active, 1), 2)::DECIMAL(10,2),
        cm.months_active::INTEGER
    FROM customer_metrics cm;
END;
$$ LANGUAGE plpgsql;

-- =================================================================
-- 10. 異常検知クエリ
-- =================================================================

-- 異常な注文パターンの検出
WITH order_anomalies AS (
    SELECT 
        customer_id,
        order_id,
        order_date,
        total_amount,
        AVG(total_amount) OVER (
            PARTITION BY customer_id 
            ORDER BY order_date 
            ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING
        ) as avg_previous_orders,
        STDDEV(total_amount) OVER (
            PARTITION BY customer_id 
            ORDER BY order_date 
            ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING
        ) as stddev_previous_orders
    FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '6 months'
),
flagged_orders AS (
    SELECT *,
        CASE 
            WHEN stddev_previous_orders > 0 AND 
                 ABS(total_amount - avg_previous_orders) > (2 * stddev_previous_orders)
            THEN 'Statistical Anomaly'
            WHEN total_amount > 5 * avg_previous_orders
            THEN 'Unusually High Amount'
            WHEN total_amount < 0.2 * avg_previous_orders AND avg_previous_orders > 50
            THEN 'Unusually Low Amount'
            ELSE 'Normal'
        END as anomaly_type
    FROM order_anomalies
    WHERE avg_previous_orders IS NOT NULL
)
SELECT 
    anomaly_type,
    COUNT(*) as occurrence_count,
    ROUND(AVG(total_amount), 2) as avg_amount,
    ROUND(MIN(total_amount), 2) as min_amount,
    ROUND(MAX(total_amount), 2) as max_amount
FROM flagged_orders
WHERE anomaly_type != 'Normal'
GROUP BY anomaly_type
ORDER BY occurrence_count DESC;

-- =================================================================
-- 11. レポート生成用クエリ
-- =================================================================

-- エグゼクティブダッシュボード用KPI
SELECT 
    'Customer Metrics' as metric_category,
    JSON_BUILD_OBJECT(
        'total_customers', (SELECT COUNT(*) FROM customers),
        'active_customers_30d', (
            SELECT COUNT(DISTINCT customer_id) 
            FROM orders 
            WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
        ),
        'new_customers_30d', (
            SELECT COUNT(*) 
            FROM customers 
            WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
        ),
        'customer_retention_rate', (
            SELECT ROUND(
                COUNT(DISTINCT CASE WHEN recent.customer_id IS NOT NULL THEN old.customer_id END)::float / 
                COUNT(DISTINCT old.customer_id) * 100, 2
            )
            FROM (
                SELECT DISTINCT customer_id 
                FROM orders 
                WHERE order_date BETWEEN CURRENT_DATE - INTERVAL '60 days' AND CURRENT_DATE - INTERVAL '30 days'
            ) old
            LEFT JOIN (
                SELECT DISTINCT customer_id 
                FROM orders 
                WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
            ) recent ON old.customer_id = recent.customer_id
        )
    ) as metrics

UNION ALL

SELECT 
    'Revenue Metrics' as metric_category,
    JSON_BUILD_OBJECT(
        'total_revenue_30d', (
            SELECT COALESCE(SUM(total_amount), 0) 
            FROM orders 
            WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
        ),
        'avg_order_value_30d', (
            SELECT ROUND(AVG(total_amount), 2) 
            FROM orders 
            WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
        ),
        'total_orders_30d', (
            SELECT COUNT(*) 
            FROM orders 
            WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
        )
    ) as metrics;

-- =================================================================
-- 実行例とパフォーマンステスト
-- =================================================================

-- 最後に、元のシンプルなクエリがどれだけ進化したかを示す
SELECT 
    'Simple Count' as analysis_type,
    COUNT(*) as result,
    'Basic customer count' as description
FROM customers

UNION ALL

SELECT 
    'Advanced Analytics' as analysis_type,
    COUNT(*) as result,
    'Customers analyzed with RFM, cohort, and behavioral patterns' as description
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.customer_id = c.customer_id 
    AND o.order_date >= CURRENT_DATE - INTERVAL '12 months'
);

-- パフォーマンス監視クエリ
SELECT 
    schemaname,
    tablename,
    attname as column_name,
    n_distinct,
    correlation
FROM pg_stats 
WHERE tablename IN ('customers', 'orders', 'order_items', 'products')
ORDER BY tablename, attname;
