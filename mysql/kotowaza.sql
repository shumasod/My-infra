-- ことわざ大辞典データベースを作成
CREATE DATABASE IF NOT EXISTS kotowaza_daijiten;

-- ことわざ大辞典データベースを使用
USE kotowaza_daijiten;

-- ことわざテーブルを作成
CREATE TABLE IF NOT EXISTS proverbs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    proverb TEXT NOT NULL,
    hiragana TEXT NOT NULL,
    romaji TEXT NOT NULL,
    meaning TEXT NOT NULL,
    literal_meaning TEXT,
    example TEXT,
    origin TEXT,
    usage_notes TEXT,
    cultural_notes TEXT,
    first_appearance_date DATE,
    popularity_score FLOAT,
    difficulty_level ENUM('easy', 'medium', 'hard') DEFAULT 'medium',
    is_common BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- カテゴリーテーブルを作成
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- 地域テーブルを作成
CREATE TABLE IF NOT EXISTS regions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    prefecture VARCHAR(50),
    geographical_area ENUM('北海道', '東北', '関東', '中部', '近畿', '中国', '四国', '九州', '沖縄')
);

-- 時代テーブルを作成
CREATE TABLE IF NOT EXISTS eras (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    start_year INT,
    end_year INT
);

-- ことわざと関連情報を紐付けるための中間テーブルを作成
CREATE TABLE IF NOT EXISTS proverb_categories (
    proverb_id INT,
    category_id INT,
    PRIMARY KEY (proverb_id, category_id),
    FOREIGN KEY (proverb_id) REFERENCES proverbs(id),
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE IF NOT EXISTS proverb_regions (
    proverb_id INT,
    region_id INT,
    PRIMARY KEY (proverb_id, region_id),
    FOREIGN KEY (proverb_id) REFERENCES proverbs(id),
    FOREIGN KEY (region_id) REFERENCES regions(id)
);

CREATE TABLE IF NOT EXISTS proverb_eras (
    proverb_id INT,
    era_id INT,
    PRIMARY KEY (proverb_id, era_id),
    FOREIGN KEY (proverb_id) REFERENCES proverbs(id),
    FOREIGN KEY (era_id) REFERENCES eras(id)
);

-- 類義語・対義語テーブルを作成
CREATE TABLE IF NOT EXISTS related_proverbs (
    proverb_id INT,
    related_proverb_id INT,
    relationship_type ENUM('similar', 'antonym', 'variant'),
    PRIMARY KEY (proverb_id, related_proverb_id),
    FOREIGN KEY (proverb_id) REFERENCES proverbs(id),
    FOREIGN KEY (related_proverb_id) REFERENCES proverbs(id)
);

-- 出典テーブルを作成
CREATE TABLE IF NOT EXISTS sources (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(100),
    publication_year INT,
    publisher VARCHAR(100),
    source_type ENUM('book', 'article', 'website', 'oral_tradition')
);

-- ことわざと出典を紐付けるための中間テーブルを作成
CREATE TABLE IF NOT EXISTS proverb_sources (
    proverb_id INT,
    source_id INT,
    page_number VARCHAR(20),
    PRIMARY KEY (proverb_id, source_id),
    FOREIGN KEY (proverb_id) REFERENCES proverbs(id),
    FOREIGN KEY (source_id) REFERENCES sources(id)
);

-- 用例テーブルを作成
CREATE TABLE IF NOT EXISTS usage_examples (
    id INT AUTO_INCREMENT PRIMARY KEY,
    proverb_id INT,
    example TEXT NOT NULL,
    context TEXT,
    source VARCHAR(255),
    FOREIGN KEY (proverb_id) REFERENCES proverbs(id)
);

-- タグテーブルを作成
CREATE TABLE IF NOT EXISTS tags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- ことわざとタグを紐付けるための中間テーブルを作成
CREATE TABLE IF NOT EXISTS proverb_tags (
    proverb_id INT,
    tag_id INT,
    PRIMARY KEY (proverb_id, tag_id),
    FOREIGN KEY (proverb_id) REFERENCES proverbs(id),
    FOREIGN KEY (tag_id) REFERENCES tags(id)
);

-- ユーザーコメントテーブルを作成
CREATE TABLE IF NOT EXISTS user_comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    proverb_id INT,
    user_name VARCHAR(100),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (proverb_id) REFERENCES proverbs(id)
);

-- サンプルデータを挿入
INSERT INTO proverbs (proverb, hiragana, romaji, meaning, literal_meaning, example, origin, usage_notes, cultural_notes, first_appearance_date, popularity_score, difficulty_level) VALUES
    ('石の上にも三年', 'いしのうえにもさんねん', 'ishi no ue ni mo sannen', '忍耐強く努力を続ければ、いつかは成功する', '石の上に三年座る', '彼は三年間毎日練習を続け、ついにコンクールで優勝した。まさに石の上にも三年だ。', '石の上で座禅を組む修行僧の姿から', '長期的な努力や忍耐が必要な状況で使用される', '日本の仏教文化と関連がある', '1700-01-01', 0.8, 'easy'),
    ('一石二鳥', 'いっせきにちょう', 'isseki nichō', '一つの行動で二つの利益を得ること', '一つの石で二羽の鳥を獲る', 'この新しい政策は、経済を活性化させつつ環境も保護できる一石二鳥の策だ。', '一つの石で二羽の鳥を打ち落とすという狩猟の方法から', 'ビジネスや戦略の文脈でよく使用される', '効率を重視する日本の文化を反映している', '1868-01-01', 0.9, 'easy'),
    ('猿も木から落ちる', 'さるもきからおちる', 'saru mo ki kara ochiru', '熟練した人でも時には失敗することがある', '猿でさえ木から落ちる', 'あの有名な料理人が今回の料理コンテストで優勝を逃したのは、まさに猿も木から落ちるだね。', '木登りが得意な猿でさえ落ちることがあるという観察から', '失敗を慰める際や、謙虚さを示す際に使用される', '日本の自然観察に基づいたことわざの一例', '1700-01-01', 0.7, 'medium');

-- カテゴリーにサンプルデータを挿入
INSERT INTO categories (name, description) VALUES 
    ('努力', '忍耐と勤勉さに関することわざ'),
    ('効率', '効果的な行動や方法に関することわざ'),
    ('失敗', '失敗やミスに関することわざ');

-- 地域にサンプルデータを挿入
INSERT INTO regions (name, prefecture, geographical_area) VALUES 
    ('全国', NULL, NULL),
    ('関東', '東京', '関東'),
    ('関西', '大阪', '近畿');

-- 時代にサンプルデータを挿入
INSERT INTO eras (name, start_year, end_year) VALUES 
    ('江戸時代', 1603, 1868),
    ('明治時代', 1868, 1912),
    ('昭和時代', 1926, 1989);

-- ことわざとカテゴリーを紐付け
INSERT INTO proverb_categories (proverb_id, category_id) VALUES
    (1, 1), -- 石の上にも三年 - 努力
    (2, 2), -- 一石二鳥 - 効率
    (3, 3); -- 猿も木から落ちる - 失敗

-- ことわざと地域を紐付け
INSERT INTO proverb_regions (proverb_id, region_id) VALUES
    (1, 1), -- 石の上にも三年 - 全国
    (2, 1), -- 一石二鳥 - 全国
    (3, 1); -- 猿も木から落ちる - 全国

-- ことわざと時代を紐付け
INSERT INTO proverb_eras (proverb_id, era_id) VALUES
    (1, 1), -- 石の上にも三年 - 江戸時代
    (2, 2), -- 一石二鳥 - 明治時代
    (3, 1); -- 猿も木から落ちる - 江戸時代

-- 類義語・対義語の関係を設定
INSERT INTO related_proverbs (proverb_id, related_proverb_id, relationship_type) VALUES
    (1, 2, 'similar'), -- 石の上にも三年 - 一石二鳥（類義語）
    (2, 3, 'antonym'); -- 一石二鳥 - 猿も木から落ちる（対義語）

-- 出典を追加
INSERT INTO sources (title, author, publication_year, publisher, source_type) VALUES
    ('日本のことわざ大全', '山田太郎', 2000, '日本出版社', 'book'),
    ('古典文学に見ることわざの起源', '鈴木花子', 1995, '文学研究所', 'article');

-- ことわざと出典を紐付け
INSERT INTO proverb_sources (proverb_id, source_id, page_number) VALUES
    (1, 1, '42'),
    (2, 2, '15-17'),
    (3, 1, '103');

-- 用例を追加
INSERT INTO usage_examples (proverb_id, example, context, source) VALUES
    (1, '新入社員の田中さんは、最初は苦戦していましたが、石の上にも三年の精神で頑張り続け、今では部署の中心的存在になりました。', 'ビジネス場面', '社内報2022年5月号'),
    (2, '新しい健康器具を買ったら、運動不足解消と部屋の掃除が同時にできて一石二鳥だった。', '日常生活', NULL),
    (3, 'オリンピック金メダリストが予選で失格したニュースを聞いて、「猿も木から落ちる」とコメンテーターが言っていた。', 'スポーツニュース', '2024年オリンピック中継');

-- タグを追加
INSERT INTO tags (name) VALUES ('ビジネス'), ('日常生活'), ('自然'), ('動物');

-- ことわざとタグを紐付け
INSERT INTO proverb_tags (proverb_id, tag_id) VALUES
    (1, 1), -- 石の上にも三年 - ビジネス
    (2, 1), -- 一石二鳥 - ビジネス
    (2, 2), -- 一石二鳥 - 日常生活
    (3, 3), -- 猿も木から落ちる - 自然
    (3, 4); -- 猿も木から落ちる - 動物

-- ユーザーコメントを追加
INSERT INTO user_comments (proverb_id, user_name, comment) VALUES
    (1, 'kotowaza_fan', 'このことわざを胸に刻んで、難しい資格試験に挑戦中です。'),
    (2, 'efficiency_expert', '経営戦略を立てる時、いつもこの言葉を意識しています。'),
    (3, 'language_learner', '日本語を勉強していて、このことわざを知ったときはとても面白いと思いました。');