

CREATE DATABASE testdb;
USE model;

CREATE TABLE company (
  company_id INT AUTO_INCREMENT PRIMARY KEY,
  company_name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE person (
  person_id INT AUTO_INCREMENT PRIMARY KEY,
  company_id INT,
  person_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES company(company_id)
);


## ダミーデータの生成

-- companyテーブル用ダミーデータ生成
DELIMITER $$
CREATE PROCEDURE `InsertCompanyData`()
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < 100000 DO
    INSERT INTO company (company_name) VALUES (CONCAT('Company ', i));
    SET i = i + 1;
  END WHILE;
END$$
DELIMITER ;
CALL InsertCompanyData();
DROP PROCEDURE IF EXISTS `InsertCompanyData`;

-- personテーブル用ダミーデータ生成
DELIMITER $$
CREATE PROCEDURE `InsertPersonData`()
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE maxCompanyID INT;
  SELECT MAX(company_id) INTO maxCompanyID FROM company;
  WHILE i < 100000 DO
    INSERT INTO person (company_id, person_name, email) VALUES (FLOOR(1 + RAND() * maxCompanyID), CONCAT('Person ', i), CONCAT('email', i, '@example.com'));
    SET i = i + 1;
  END WHILE;
END$$
DELIMITER ;
CALL InsertPersonData();
DROP PROCEDURE IF EXISTS `InsertPersonData`;
