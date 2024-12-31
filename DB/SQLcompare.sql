-- 1. 一時テーブルの作成
CREATE TEMPORARY TABLE temp_table (
    id INT,
    column1 VARCHAR(255),
    column2 VARCHAR(255)
);

-- 2. CSVファイルからデータを読み込む
LOAD DATA INFILE '/path/to/your/file.csv'
INTO TABLE temp_table
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 3. 既存のテーブルと一時テーブルの比較クエリ
SELECT 
    t1.id,
    t1.column1 AS existing_column1,
    t2.column1 AS csv_column1,
    t1.column2 AS existing_column2,
    t2.column2 AS csv_column2
FROM 
    existing_table t1
LEFT JOIN 
    temp_table t2 ON t1.id = t2.id
WHERE 
    t1.column1 <> t2.column1 OR
    t1.column2 <> t2.column2 OR
    t2.id IS NULL

UNION

SELECT 
    t2.id,
    t1.column1 AS existing_column1,
    t2.column1 AS csv_column1,
    t1.column2 AS existing_column2,
    t2.column2 AS csv_column2
FROM 
    temp_table t2
LEFT JOIN 
    existing_table t1 ON t2.id = t1.id
WHERE 
    t1.id IS NULL;

-- 4. 比較が終わったら一時テーブルを削除（オプション）
DROP TEMPORARY TABLE IF EXISTS temp_table;
