-- 1. 外部キー制約の整合性チェック
SELECT 
    tc.table_schema, 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    (SELECT COUNT(*) 
     FROM information_schema.tables t
     LEFT JOIN information_schema.columns c 
        ON c.table_name = t.table_name 
        AND c.table_schema = t.table_schema
     WHERE t.table_schema = tc.table_schema 
        AND t.table_name = tc.table_name
        AND c.column_name = kcu.column_name
        AND NOT EXISTS (
            SELECT 1 
            FROM information_schema.tables ft
            LEFT JOIN information_schema.columns fc 
                ON fc.table_name = ft.table_name 
                AND fc.table_schema = ft.table_schema
            WHERE ft.table_schema = ccu.table_schema 
                AND ft.table_name = ccu.table_name
                AND fc.column_name = ccu.column_name
        )
    ) AS inconsistent_count
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
HAVING inconsistent_count > 0;
