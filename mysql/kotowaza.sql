-- ことわざ大辞典データベースを作成
CREATE DATABASE IF NOT EXISTS kotowaza_daijiten;

-- ことわざ大辞典データベースを使用
USE kotowaza_daijiten;

-- ことわざテーブルを作成
CREATE TABLE IF NOT EXISTS proverbs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    proverb TEXT NOT NULL,
    hiragana TEXT NOT NULL,
    meaning TEXT NOT NULL,
    example TEXT,
    origin TEXT,
    category VARCHAR(50),
    region VARCHAR(50),
    era VARCHAR(50),
    similar_proverbs TEXT,
    antonym_proverbs TEXT,
    usage_level ENUM('common', 'uncommon', 'rare') DEFAULT 'common',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- カテゴリーテーブルを作成
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- 地域テーブルを作成
CREATE TABLE IF NOT EXISTS regions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- 時代テーブルを作成
CREATE TABLE IF NOT EXISTS eras (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- サンプルデータを挿入
INSERT INTO proverbs (proverb, hiragana, meaning, example, origin, category, region, era, similar_proverbs, antonym_proverbs, usage_level) VALUES
    ('石の上にも三年', 'いしのうえにもさんねん', '忍耐強く努力を続ければ、いつかは成功する', '彼は三年間毎日練習を続け、ついにコンクールで優勝した。まさに石の上にも三年だ。', '石の上で座禅を組む修行僧の姿から', '努力', '全国', '江戸時代', '継続は力なり', '三日坊主', 'common'),
    ('一石二鳥', 'いっせきにちょう', '一つの行動で二つの利益を得ること', 'この新しい政策は、経済を活性化させつつ環境も保護できる一石二鳥の策だ。', '一つの石で二羽の鳥を打ち落とすという狩猟の方法から', '効率', '全国', '明治時代', '一挙両得', '効率が悪い', 'common'),
    ('猿も木から落ちる', 'さるもきからおちる', '熟練した人でも時には失敗することがある', 'あの有名な料理人が今回の料理コンテストで優勝を逃したのは、まさに猿も木から落ちるだね。', '木登りが得意な猿でさえ落ちることがあるという観察から', '失敗', '全国', '江戸時代', '弘法にも筆の誤り', '完璧', 'common');

-- カテゴリーにサンプルデータを挿入
INSERT INTO categories (name) VALUES ('努力'), ('効率'), ('失敗');

-- 地域にサンプルデータを挿入
INSERT INTO regions (name) VALUES ('全国'), ('関東'), ('関西');

-- 時代にサンプルデータを挿入
INSERT INTO eras (name) VALUES ('江戸時代'), ('明治時代'), ('昭和時代');