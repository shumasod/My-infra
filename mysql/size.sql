-- 3. テーブルの肥大化を確認
SELECT 
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    round(n_dead_tup::numeric / nullif(n_live_tup, 0), 4) AS dead_ratio
FROM pg_stat_user_tables
WHERE n_live_tup > 100000
ORDER BY dead_ratio DESC;
