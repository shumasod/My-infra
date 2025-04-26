-- データベースの作成
CREATE DATABASE IF NOT EXISTS customer_database;
USE customer_database;

-- 顧客テーブル
CREATE TABLE IF NOT EXISTS customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(10) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(20),
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1万人のダミーデータ挿入（例）
DELIMITER //
CREATE PROCEDURE InsertDummyCustomers(IN numberOfCustomers INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    WHILE i < numberOfCustomers DO
        INSERT INTO customers (first_name, last_name, email, phone_number, address, city, state, postal_code, country)
        VALUES (
            CONCAT('FirstName', i),
            CONCAT('LastName', i),
            CONCAT('customer', i, '@example.com'),
            CONCAT('+1-555-555-', LPAD(i, 4, '0')),
            CONCAT('Address', i),
            CONCAT('City', i),
            CONCAT('State', i),
            CONCAT('Postal', i, 'Code'),
            'Country'
        );
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

-- ダミーデータの挿入（10万人分）
CALL InsertDummyCustomers(100000);
