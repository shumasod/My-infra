# MongoDBビギナーズガイド

## 目次
1. [MongoDBとは](#mongodbとは)
2. [基本概念](#基本概念)
3. [インストールと設定](#インストールと設定)
4. [基本的な操作](#基本的な操作)
5. [実践的な例](#実践的な例)

## MongoDBとは
MongoDBは、柔軟でスケーラブルなNoSQLデータベースです。従来のリレーショナルデータベース（MySQL、PostgreSQLなど）とは異なり、データをJSONライクなドキュメント形式で保存します。

### MongoDBの特徴
- ドキュメント指向
- スキーマレス
- 水平スケーリングが容易
- 高速なデータ処理

## 基本概念
MongoDBを理解する上で重要な概念を説明します。

### データベース構造
```
データベース
    └── コレクション（テーブルに相当）
        └── ドキュメント（レコードに相当）
```

### ドキュメントの例
```javascript
{
    "name": "田中太郎",
    "age": 25,
    "hobbies": ["読書", "旅行"],
    "address": {
        "city": "東京",
        "district": "渋谷区"
    }
}
```

## インストールと設定

### Windows での場合
1. MongoDBの公式サイトからインストーラーをダウンロード
2. インストーラーを実行（「Complete」設定を推奨）
3. MongoDB Compassもインストール（GUIツール）

### Mac での場合
```bash
# Homebrewを使用してインストール
brew tap mongodb/brew
brew install mongodb-community
```

## 基本的な操作

### 1. データベースの操作
```javascript
// データベースの作成と選択
use myFirstDB

// 現在のデータベースを確認
db

// すべてのデータベースを表示
show dbs
```

### 2. コレクションの操作
```javascript
// コレクションの作成
db.createCollection("users")

// コレクションの一覧表示
show collections
```

### 3. ドキュメントの操作

#### 作成（Create）
```javascript
// 1件のドキュメントを挿入
db.users.insertOne({
    name: "田中太郎",
    age: 25,
    email: "tanaka@example.com"
})

// 複数のドキュメントを一括挿入
db.users.insertMany([
    {
        name: "山田花子",
        age: 30,
        email: "yamada@example.com"
    },
    {
        name: "佐藤次郎",
        age: 35,
        email: "sato@example.com"
    }
])
```

#### 読み取り（Read）
```javascript
// すべてのドキュメントを取得
db.users.find()

// 条件を指定して取得
db.users.find({ age: { $gt: 30 } })

// 特定のフィールドのみ取得
db.users.find({}, { name: 1, email: 1 })
```

#### 更新（Update）
```javascript
// 1件のドキュメントを更新
db.users.updateOne(
    { name: "田中太郎" },
    { $set: { age: 26 } }
)

// 複数のドキュメントを更新
db.users.updateMany(
    { age: { $gt: 30 } },
    { $set: { status: "シニア会員" } }
)
```

#### 削除（Delete）
```javascript
// 1件のドキュメントを削除
db.users.deleteOne({ name: "田中太郎" })

// 複数のドキュメントを削除
db.users.deleteMany({ age: { $lt: 20 } })
```

## 実践的な例

### ユーザー管理システムの例
```javascript
// ユーザーコレクションの作成と基本的なバリデーション
db.createCollection("users", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["name", "email", "age"],
            properties: {
                name: {
                    bsonType: "string",
                    description: "名前は必須です"
                },
                email: {
                    bsonType: "string",
                    pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
                    description: "有効なメールアドレスが必要です"
                },
                age: {
                    bsonType: "int",
                    minimum: 0,
                    description: "年齢は0以上の整数である必要があります"
                }
            }
        }
    }
})

// ユーザーの追加
db.users.insertOne({
    name: "新規ユーザー",
    email: "new.user@example.com",
    age: 28,
    registeredAt: new Date(),
    preferences: {
        newsletter: true,
        theme: "dark"
    }
})

// メールアドレスでユーザーを検索
db.users.findOne({ email: "new.user@example.com" })

// 年齢で並べ替えてユーザーを取得
db.users.find().sort({ age: 1 })
```

### よく使用する演算子
- `$eq`: 等しい
- `$gt`: より大きい
- `$lt`: より小さい
- `$gte`: 以上
- `$lte`: 以下
- `$in`: 配列内の値のいずれかに一致
- `$nin`: 配列内の値のいずれにも一致しない

### 検索の例
```javascript
// 30歳以上のユーザーを検索
db.users.find({ age: { $gte: 30 } })

// 特定の趣味を持つユーザーを検索
db.users.find({ hobbies: { $in: ["読書", "旅行"] } })

// メールアドレスが指定のドメインのユーザーを検索
db.users.find({ email: /example\.com$/ })
```

## 練習問題
1. 新しいデータベース「practice_db」を作成してください。
2. その中に「students」コレクションを作成してください。
3. 3人分の生徒データを追加してください。
4. 20歳以上の生徒を検索してください。
5. 特定の生徒の年齢を更新してください。

### 解答例
```javascript
// 1. データベースの作成
use practice_db

// 2. コレクションの作成
db.createCollection("students")

// 3. データの追加
db.students.insertMany([
    { name: "学生A", age: 18, grade: "1年生" },
    { name: "学生B", age: 20, grade: "2年生" },
    { name: "学生C", age: 22, grade: "3年生" }
])

// 4. 20歳以上の検索
db.students.find({ age: { $gte: 20 } })

// 5. 年齢の更新
db.students.updateOne(
    { name: "学生A" },
    { $set: { age: 19 } }
)
```

## まとめ
- MongoDBはドキュメント指向のNoSQLデータベース
- JSONライクな形式でデータを保存
- 基本的なCRUD操作を習得することが重要
- 実践的な例を通じて理解を深めることが大切

次のステップ：
1. MongoDB Compassを使用したGUI操作の練習
2. インデックスの作成と活用
3. アグリゲーションパイプラインの学習
4. バックアップとリストアの方法
