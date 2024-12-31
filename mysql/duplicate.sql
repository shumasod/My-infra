- 2. 重複データのチェック
SELECT 
    table_schema, 
    table_name, 
    column_name, 
    COUNT(*) AS duplicate_count
FROM (
    SELECT 
        table_schema, 
        table_name, 
        column_name, 
        COUNT(*) OVER (
            PARTITION BY table_schema, table_name, column_name
        ) AS column_count
    FROM information_schema.columns
    WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
) AS subquery
WHERE column_count > 1
GROUP BY table_schema, table_name, column_name
ORDER BY duplicate_count DESC;
