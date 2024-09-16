-- 1. インデックスの使用状況を確認
SELECT 
    t.schemaname,
    t.tablename,
    c.reltuples::bigint AS row_estimate,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    psui.indexrelname AS index_name,
    psui.idx_scan AS index_scans
FROM pg_tables t
LEFT JOIN pg_class c ON t.tablename = c.relname
LEFT JOIN pg_stat_user_indexes psui ON c.oid = psui.relid
WHERE t.schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(c.oid) DESC;
