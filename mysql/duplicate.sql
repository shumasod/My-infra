-- ユニーク制約を持つ列の情報を取得
WITH unique_columns AS (
    SELECT 
        tc.table_schema,
        tc.table_name,
        kcu.column_name
    FROM 
        information_schema.table_constraints tc
    JOIN 
        information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
    WHERE 
        tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
        AND tc.table_schema NOT IN ('information_schema', 'pg_catalog')
)
-- 各テーブルごとに動的SQLを生成して実行する必要がある
-- 実際の実装はストアドプロシージャなどで行うことになります
SELECT 
    table_schema,
    table_name,
    column_name,
    CONCAT('SELECT COUNT(*) - COUNT(DISTINCT ', column_name, ') AS duplicate_count FROM ', 
           table_schema, '.', table_name) AS check_query
FROM 
    unique_columns
ORDER BY 
    table_schema, 
    table_name;
