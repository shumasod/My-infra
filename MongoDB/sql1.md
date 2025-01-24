MongoDBのデータベース構築に関する基本的なクエリをご紹介します。実際のユースケースに即した具体的なものを作成いたしますが、まずは基本的な構文をお示しします。



1. データベースの作成と使用:
```javascript
use myDatabase
```

2. コレクションの作成:
```javascript
db.createCollection("users")
```

3. ドキュメントの挿入:
```javascript
// 1件のドキュメントを挿入
db.users.insertOne({
    name: "田中太郎",
    age: 30,
    email: "tanaka@example.com"
})

// 複数のドキュメントを挿入
db.users.insertMany([
    {
        name: "山田花子",
        age: 25,
        email: "yamada@example.com"
    },
    {
        name: "佐藤次郎",
        age: 35,
        email: "sato@example.com"
    }
])
```

4. インデックスの作成:
```javascript
// 単一フィールドのインデックス
db.users.createIndex({ email: 1 })

// 複合インデックス
db.users.createIndex({ name: 1, age: -1 })
```

5. バリデーションルールの設定:
```javascript
db.createCollection("products", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["name", "price"],
            properties: {
                name: {
                    bsonType: "string",
                    description: "商品名 - 必須項目"
                },
                price: {
                    bsonType: "number",
                    minimum: 0,
                    description: "価格 - 必須項目、0以上の数値"
                }
            }
        }
    }
})
```

