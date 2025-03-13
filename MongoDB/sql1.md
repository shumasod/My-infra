# MongoDB データベース構築ガイド

## 目次
- [概要](#概要)
- [前提条件](#前提条件)
- [1. データベースの作成と使用](#1-データベースの作成と使用)
- [2. コレクションの作成](#2-コレクションの作成)
- [3. ドキュメントの挿入](#3-ドキュメントの挿入)
- [4. ドキュメントの検索](#4-ドキュメントの検索)
- [5. ドキュメントの更新](#5-ドキュメントの更新)
- [6. ドキュメントの削除](#6-ドキュメントの削除)
- [7. インデックスの作成と管理](#7-インデックスの作成と管理)
- [8. スキーマバリデーション](#8-スキーマバリデーション)
- [9. アグリゲーション](#9-アグリゲーション)
- [10. トランザクション](#10-トランザクション)
- [ベストプラクティス](#ベストプラクティス)
- [参考リンク](#参考リンク)

## 概要

本ガイドはMongoDB v6.0以降を対象とした、データベース構築のための基本的なクエリや操作方法を解説します。MongoDB Shell（`mongosh`）を使用した例を中心に説明します。

## 前提条件

- MongoDB サーバー（v6.0以降）がインストールされていること
- MongoDB Shell（`mongosh`）がインストールされていること
- 基本的なJavaScript知識があること

## 1. データベースの作成と使用

MongoDBでは、データベースを明示的に作成する必要はありません。データベースに初めてデータを保存するときに自動的に作成されます。

```javascript
// データベースの使用（存在しない場合は後でデータが保存された時点で作成される）
use myDatabase

// 現在使用中のデータベースを確認
db.getName()
// 出力: myDatabase

// 全データベースのリストを表示
show dbs
// 出力:
// admin       0.000GB
// config      0.000GB
// local       0.000GB
// myDatabase  0.000GB (データが保存されている場合のみ表示)
```

**注意点**:
- データベース名は大文字小文字を区別します
- データベース名に使用できない文字（`/`, `\`, `.`, `"`, `$`, `*`, `<`, `>`, `:`, `|`, `?`, スペース）があります
- データベースにコレクションやドキュメントが保存されるまで、`show dbs`コマンドの出力に表示されません

## 2. コレクションの作成

コレクションは、ドキュメントを格納するコンテナです。RDBMSのテーブルに相当します。

```javascript
// 明示的にコレクションを作成
db.createCollection("users")
// 出力: { "ok" : 1 }

// 現在のデータベース内のコレクション一覧を表示
show collections
// 出力: users

// コレクションの詳細情報を取得
db.users.stats()
// 出力: コレクションの統計情報
```

**暗黙的な作成**:
最初のドキュメントを挿入するときに、指定したコレクションが存在しない場合は自動的に作成されます。

```javascript
// コレクションが存在しなくても自動的に作成される
db.customers.insertOne({ name: "鈴木一郎", age: 28 })
// 出力: {
//   "acknowledged" : true,
//   "insertedId" : ObjectId("...")
// }

show collections
// 出力:
// customers
// users
```

## 3. ドキュメントの挿入

MongoDBの基本的なデータ単位はドキュメントで、JSONライクなBSON（Binary JSON）形式で表現されます。

### 単一ドキュメントの挿入

```javascript
// 1件のドキュメントを挿入
db.users.insertOne({
    name: "田中太郎",
    age: 30,
    email: "tanaka@example.com",
    address: {
        city: "東京",
        prefecture: "東京都",
        postalCode: "100-0001"
    },
    tags: ["premium", "verified"],
    createdAt: new Date()
})
// 出力: {
//   "acknowledged" : true,
//   "insertedId" : ObjectId("...")
// }
```

### 複数ドキュメントの挿入

```javascript
// 複数のドキュメントを挿入
db.users.insertMany([
    {
        name: "山田花子",
        age: 25,
        email: "yamada@example.com",
        address: {
            city: "大阪",
            prefecture: "大阪府",
            postalCode: "530-0001"
        },
        tags: ["new"],
        createdAt: new Date()
    },
    {
        name: "佐藤次郎",
        age: 35,
        email: "sato@example.com",
        address: {
            city: "名古屋",
            prefecture: "愛知県",
            postalCode: "460-0001"
        },
        tags: ["premium"],
        createdAt: new Date()
    }
])
// 出力: {
//   "acknowledged" : true,
//   "insertedIds" : [
//     ObjectId("..."),
//     ObjectId("...")
//   ]
// }
```

**ドキュメントID**:

`_id`フィールドを明示的に指定しない場合、MongoDBは自動的に一意の`ObjectId`を生成します。

```javascript
// カスタムIDを指定
db.users.insertOne({
    _id: "user-123",
    name: "高橋五郎",
    email: "takahashi@example.com"
})
// 出力: {
//   "acknowledged" : true,
//   "insertedId" : "user-123"
// }
```

**注意点**:
- `insertMany()`では、デフォルトで一括挿入中にエラーが発生した場合、それ以前の挿入は維持されます。これを変更するには`ordered: false`オプションを設定します。
- ドキュメントのサイズは最大16MBに制限されています。

## 4. ドキュメントの検索

### 基本的な検索

```javascript
// コレクション内のすべてのドキュメントを検索
db.users.find()

// 結果を見やすくフォーマット
db.users.find().pretty()

// 特定のフィールドの値で検索
db.users.find({ name: "田中太郎" })

// 条件に一致する最初の1件のみ取得
db.users.findOne({ age: 30 })
```

### クエリオペレータ

```javascript
// 比較オペレータ
db.users.find({ age: { $gt: 25 } })  // 25歳より上
db.users.find({ age: { $gte: 25 } }) // 25歳以上
db.users.find({ age: { $lt: 35 } })  // 35歳未満
db.users.find({ age: { $lte: 35 } }) // 35歳以下
db.users.find({ age: { $ne: 30 } })  // 30歳ではない
db.users.find({ age: { $in: [25, 30, 35] } }) // 25, 30, 35歳のいずれか

// 論理オペレータ
db.users.find({ $and: [{ age: { $gt: 25 } }, { age: { $lt: 35 } }] }) // 25歳超かつ35歳未満
db.users.find({ $or: [{ age: 25 }, { age: 35 }] }) // 25歳または35歳

// 正規表現を使用した検索
db.users.find({ name: /^田/ }) // '田'で始まる名前

// ネストされたフィールドの検索
db.users.find({ "address.city": "東京" })

// 配列内の要素で検索
db.users.find({ tags: "premium" })

// 存在チェック
db.users.find({ address: { $exists: true } }) // addressフィールドが存在するドキュメント
```

### プロジェクション（返却フィールドの制限）

```javascript
// 特定のフィールドのみを返す（1:表示, 0:非表示）
db.users.find({}, { name: 1, email: 1, _id: 0 })

// ネストされたフィールドの指定
db.users.find({}, { name: 1, "address.city": 1 })
```

### カーソル操作

```javascript
// 結果のソート（1:昇順, -1:降順）
db.users.find().sort({ age: 1 })

// 結果の制限
db.users.find().limit(2)

// スキップ（ページネーションなどに利用）
db.users.find().skip(1).limit(2)

// 結果のカウント
db.users.countDocuments({ age: { $gt: 30 } })
```

## 5. ドキュメントの更新

### 単一ドキュメントの更新

```javascript
// フィールドの値を更新
db.users.updateOne(
    { name: "田中太郎" },
    { $set: { age: 31, "address.city": "横浜" } }
)
// 出力: {
//   "acknowledged" : true,
//   "matchedCount" : 1,
//   "modifiedCount" : 1
// }

// フィールドの値を増加
db.users.updateOne(
    { name: "田中太郎" },
    { $inc: { age: 1 } } // 年齢を1増加
)

// フィールドの削除
db.users.updateOne(
    { name: "山田花子" },
    { $unset: { tags: "" } }
)

// 存在しない場合は挿入（upsert）
db.users.updateOne(
    { name: "伊藤誠" },
    { $set: { age: 40, email: "ito@example.com" } },
    { upsert: true }
)
```

### 複数ドキュメントの更新

```javascript
// 条件に一致するすべてのドキュメントを更新
db.users.updateMany(
    { age: { $lt: 30 } },
    { $set: { status: "young" } }
)
// 出力: {
//   "acknowledged" : true,
//   "matchedCount" : x,
//   "modifiedCount" : x
// }
```

### 配列演算子を使った更新

```javascript
// 配列に要素を追加（重複なし）
db.users.updateOne(
    { name: "佐藤次郎" },
    { $addToSet: { tags: "loyal" } }
)

// 配列に要素を追加（重複あり）
db.users.updateOne(
    { name: "佐藤次郎" },
    { $push: { tags: "returning" } }
)

// 配列から要素を削除
db.users.updateOne(
    { name: "佐藤次郎" },
    { $pull: { tags: "premium" } }
)
```

### ドキュメントの置換

```javascript
// ドキュメント全体を置換（_idは維持）
db.users.replaceOne(
    { name: "高橋五郎" },
    {
        name: "高橋五郎",
        age: 45,
        email: "takahashi.new@example.com",
        department: "営業部"
    }
)
```

## 6. ドキュメントの削除

```javascript
// 条件に一致する単一ドキュメントを削除
db.users.deleteOne({ name: "山田花子" })
// 出力: {
//   "acknowledged" : true,
//   "deletedCount" : 1
// }

// 条件に一致するすべてのドキュメントを削除
db.users.deleteMany({ age: { $lt: 25 } })

// コレクション内のすべてのドキュメントを削除
db.users.deleteMany({})

// コレクション自体を削除
db.users.drop()
// 出力: true
```

## 7. インデックスの作成と管理

インデックスはクエリのパフォーマンスを向上させます。特に大量のデータを扱う場合は重要です。

### インデックスの作成

```javascript
// 単一フィールドのインデックス（1:昇順, -1:降順）
db.users.createIndex({ email: 1 })
// 出力: "email_1"

// 複合インデックス
db.users.createIndex({ name: 1, age: -1 })
// 出力: "name_1_age_-1"

// ユニークインデックス
db.users.createIndex({ email: 1 }, { unique: true })

// TTL（Time To Live）インデックス - 指定時間経過後にドキュメントを自動削除
db.sessions.createIndex({ lastAccessed: 1 }, { expireAfterSeconds: 3600 })

// テキストインデックス - 全文検索用
db.articles.createIndex({ content: "text" })

// ジオスペーシャルインデックス - 位置情報クエリ用
db.places.createIndex({ location: "2dsphere" })
```

### インデックスの管理

```javascript
// コレクションのインデックス一覧を表示
db.users.getIndexes()

// インデックスの削除
db.users.dropIndex("email_1")

// すべてのインデックスを削除（_id インデックスは除く）
db.users.dropIndexes()

// インデックスの使用状況を確認
db.users.find({ email: "tanaka@example.com" }).explain("executionStats")
```

## 8. スキーマバリデーション

MongoDBはスキーマレスですが、バリデーションルールを設定することでデータの整合性を確保できます。

```javascript
// バリデーションルールを持つコレクションを作成
db.createCollection("products", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["name", "price", "category"],
            properties: {
                name: {
                    bsonType: "string",
                    description: "商品名 - 必須項目、文字列"
                },
                price: {
                    bsonType: "number",
                    minimum: 0,
                    description: "価格 - 必須項目、0以上の数値"
                },
                category: {
                    enum: ["電子機器", "家具", "文房具", "食品", "衣類"],
                    description: "カテゴリ - 必須項目、指定された値のいずれか"
                },
                description: {
                    bsonType: "string",
                    description: "商品説明 - 文字列（オプション）"
                },
                tags: {
                    bsonType: "array",
                    items: {
                        bsonType: "string"
                    },
                    description: "タグ - 文字列の配列（オプション）"
                },
                stock: {
                    bsonType: "object",
                    required: ["quantity"],
                    properties: {
                        quantity: {
                            bsonType: "int",
                            minimum: 0,
                            description: "在庫数 - 整数、0以上"
                        },
                        warehouse: {
                            bsonType: "string",
                            description: "倉庫の場所（オプション）"
                        }
                    }
                }
            }
        }
    },
    validationLevel: "strict",  // strict（すべてのドキュメント）または moderate（更新のみ）
    validationAction: "error"   // error（拒否）または warn（警告のみ）
})
```

既存のコレクションにバリデーションを追加する場合：

```javascript
db.runCommand({
    collMod: "users",
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["name", "email"],
            properties: {
                name: {
                    bsonType: "string"
                },
                email: {
                    bsonType: "string",
                    pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
                },
                age: {
                    bsonType: "int",
                    minimum: 0,
                    maximum: 120
                }
            }
        }
    },
    validationLevel: "moderate",
    validationAction: "warn"
})
```

## 9. アグリゲーション

アグリゲーションフレームワークを使用すると、ドキュメントの変換や集計が可能になります。

```javascript
// 年齢ごとのユーザー数をカウント
db.users.aggregate([
    { $group: { _id: "$age", count: { $sum: 1 } } },
    { $sort: { _id: 1 } }
])

// 都市ごとのユーザー平均年齢を集計
db.users.aggregate([
    { $match: { "address.city": { $exists: true } } },
    { $group: {
        _id: "$address.city",
        averageAge: { $avg: "$age" },
        count: { $sum: 1 }
    }},
    { $sort: { averageAge: -1 } }
])

// $lookupを使用したJOIN操作
db.orders.aggregate([
    { $match: { status: "complete" } },
    { $lookup: {
        from: "users",
        localField: "userId",
        foreignField: "_id",
        as: "userDetails"
    }},
    { $unwind: "$userDetails" },
    { $project: {
        orderId: 1,
        orderDate: 1,
        customerName: "$userDetails.name",
        totalAmount: 1
    }}
])

// 月ごとの売上集計
db.sales.aggregate([
    { $match: { date: { $gte: new Date("2023-01-01"), $lt: new Date("2024-01-01") } } },
    { $addFields: {
        month: { $month: "$date" },
        year: { $year: "$date" }
    }},
    { $group: {
        _id: { year: "$year", month: "$month" },
        totalSales: { $sum: "$amount" },
        count: { $sum: 1 }
    }},
    { $sort: { "_id.year": 1, "_id.month": 1 } }
])
```

## 10. トランザクション

MongoDB 4.0以降ではマルチドキュメントトランザクションがサポートされています（レプリカセット環境が必要）。

```javascript
// セッションの開始
const session = db.getMongo().startSession()
session.startTransaction()

try {
    const usersCollection = session.getDatabase("myDatabase").users
    const ordersCollection = session.getDatabase("myDatabase").orders
    
    // 口座残高の更新
    usersCollection.updateOne(
        { _id: "user123" },
        { $inc: { balance: -100 } }
    )
    
    // 注文の作成
    ordersCollection.insertOne({
        userId: "user123",
        product: "Laptop",
        price: 100,
        orderDate: new Date()
    })
    
    // トランザクションのコミット
    session.commitTransaction()
    console.log("トランザクションが成功しました")
} catch (error) {
    // エラー発生時はロールバック
    session.abortTransaction()
    console.error("トランザクションがロールバックされました:", error)
} finally {
    // セッションを終了
    session.endSession()
}
```

## ベストプラクティス

### 1. データモデリング

- **埋め込み vs 参照**: 一対多の関係では、「多」側が少数の場合は埋め込み、多数の場合は参照を使用
- **スキーマの設計**: アクセスパターンに基づいてスキーマを設計
- **非正規化**: 頻繁に一緒に読み取られるデータを非正規化して、JOINを減らす

### 2. インデックス

- クエリパターンに基づいてインデックスを作成
- 複合インデックスを使用する場合は、等価比較（`{ field: "value" }`）を先に配置
- 使用していないインデックスを定期的に確認し削除
- インデックスの数が多すぎると挿入/更新パフォーマンスに影響するため注意

### 3. クエリとパフォーマンス

- 大規模なドキュメントセットを扱う場合はページネーションを使用（`.skip().limit()`）
- 複雑なクエリはアグリゲーションパイプラインを活用
- `.explain()`を使用してクエリプランを分析
- 射影（プロジェクション）を使用して必要なフィールドのみを取得

### 4. 運用

- レプリカセットを使用して高可用性を確保
- 定期的なバックアップを実施
- 監視とアラートを設定（接続数、操作レイテンシなど）
- クエリのロギングとプロファイリングを活用してボトルネックを特定

## 参考リンク

- [MongoDB 公式ドキュメント](https://docs.mongodb.com/)
- [MongoDB 大学（無料のオンラインコース）](https://university.mongodb.com/)
- [MongoDB Atlas（クラウドサービス）](https://www.mongodb.com/cloud/atlas)
- [MongoDB コンパス（GUIツール）](https://www.mongodb.com/products/compass)
