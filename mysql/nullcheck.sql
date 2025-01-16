-- 3. NULL値の割合チェック
SELECT
    table_schema,
    table_name,
    column_name,
    (COUNT(*) - COUNT(column_name)) * 100.0 / COUNT(*) AS null_percentage
FROM information_schema.columns
CROSS JOIN LATERAL (
    SELECT COUNT(*) AS total_count
    FROM information_schema.tables
    WHERE table_schema = columns.table_schema
    AND table_name = columns.table_name
) AS t
WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
GROUP BY table_schema, table_name, column_name, t.total_count
HAVING (COUNT(*) - COUNT(column_name)) * 100.0 / COUNT(*) > 10
ORDER BY null_percentage DESC;
