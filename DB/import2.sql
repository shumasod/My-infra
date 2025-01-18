-- テーブル名を指定（既存のテーブル名に置き換えてください）
SET @table_name = 'your_table_name';

-- CSVファイルのパスを指定
SET @csv_file = '';

-- CSVファイルからデータを読み込んでテーブルに挿入
LOAD DATA INFILE @csv_file
INTO TABLE @table_name
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;  -- CSVファイルにヘッダー行がある場合

-- 挿入されたレコード数を確認
SELECT COUNT(*) AS inserted_records FROM @table_name;