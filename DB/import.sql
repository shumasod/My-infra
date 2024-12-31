-- テーブルが存在しない場合は作成（列名とデータ型は適宜調整してください）
CREATE TABLE IF NOT EXISTS test.test_table (
    column1 VARCHAR(255),
    column2 VARCHAR(255),
    column3 INT
    -- 他の必要な列を追加
);

-- CSVファイルからデータをインポート
LOAD DATA LOCAL INFILE ''
INTO TABLE test.test_table
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;  -- CSVファイルにヘッダーがある場合

-- インポートされたレコード数を確認
SELECT COUNT(*) AS imported_records FROM test.test_table;