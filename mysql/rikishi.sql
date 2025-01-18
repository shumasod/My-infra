-- データベースの作成
CREATE DATABASE sumo_database;

-- データベースに接続
\c sumo_database;

-- 力士テーブルの作成
CREATE TABLE wrestlers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    rank VARCHAR(50) NOT NULL,
    weight INT NOT NULL,
    height INT NOT NULL
);

-- 対戦テーブルの作成
CREATE TABLE matches (
    id SERIAL PRIMARY KEY,
    wrestler1_id INT NOT NULL,
    wrestler2_id INT NOT NULL,
    date DATE NOT NULL,
    winner_id INT,
    FOREIGN KEY (wrestler1_id) REFERENCES wrestlers(id),
    FOREIGN KEY (wrestler2_id) REFERENCES wrestlers(id),
    FOREIGN KEY (winner_id) REFERENCES wrestlers(id)
);

-- サンプル力士データの挿入
INSERT INTO wrestlers (name, rank, weight, height) VALUES
('白鵬', '横綱', 155, 192),
('鶴竜', '横綱', 160, 190),
('朝乃山', '大関', 175, 188),
('照ノ富士', '大関', 170, 192),
('正代', '関脇', 165, 186);

-- サンプル対戦データの挿入
INSERT INTO matches (wrestler1_id, wrestler2_id, date, winner_id) VALUES
(1, 2, '2024-08-26', 1),
(3, 4, '2024-08-26', 4),
(1, 3, '2024-08-27', 1),
(2, 5, '2024-08-27', 2),
(4, 5, '2024-08-28', 4);

-- 対戦結果の表示
SELECT 
    m.date,
    w1.name AS wrestler1,
    w2.name AS wrestler2,
    CASE 
        WHEN m.winner_id = w1.id THEN w1.name
        WHEN m.winner_id = w2.id THEN w2.name
        ELSE 'Draw'
    END AS winner
FROM 
    matches m
JOIN 
    wrestlers w1 ON m.wrestler1_id = w1.id
JOIN 
    wrestlers w2 ON m.wrestler2_id = w2.id
ORDER BY 
    m.date;

-- 力士の勝利数ランキング
SELECT 
    w.name,
    w.rank,
    COUNT(*) AS wins
FROM 
    matches m
JOIN 
    wrestlers w ON m.winner_id = w.id
GROUP BY 
    w.id, w.name, w.rank
ORDER BY 
    wins DESC;