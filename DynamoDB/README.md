はい、DynamoDBのテーブル設計とクエリについてマークダウン形式で解説します。

# DynamoDBテーブル設計とクエリパターン解説

## 1. テーブル基本設計

### 1.1 キースキーマ
```javascript
{
  TableName: 'Orders',
  KeySchema: [
    { AttributeName: 'PK', KeyType: 'HASH' },  // パーティションキー
    { AttributeName: 'SK', KeyType: 'RANGE' }  // ソートキー
  ]
}
```

### 1.2 インデックス設定
* プライマリインデックス
  - PK (パーティションキー): ユーザーID
  - SK (ソートキー): 注文日

* グローバルセカンダリインデックス (GSI1)
  - GSI1PK: 注文ステータス
  - GSI1SK: 注文日

## 2. データモデリング例

### 2.1 注文アイテムの構造
```javascript
{
  PK: 'USER#123',           // ユーザーID
  SK: 'ORDER#2024-01-01',   // 注文日
  orderId: 'ORD-001',
  userId: '123',
  orderDate: '2024-01-01',
  status: 'COMPLETED',
  total: 5000,
  items: [
    { productId: 'P1', quantity: 2, price: 1500 },
    { productId: 'P2', quantity: 1, price: 2000 }
  ],
  GSI1PK: 'ORDER#COMPLETED',
  GSI1SK: '2024-01-01'
}
```

## 3. 主要クエリパターン

### 3.1 ユーザーの注文履歴取得
```javascript
{
  TableName: 'Orders',
  KeyConditionExpression: 'PK = :userId',
  ExpressionAttributeValues: {
    ':userId': 'USER#123'
  }
}
```

### 3.2 期間指定での注文取得
```javascript
{
  TableName: 'Orders',
  KeyConditionExpression: 'PK = :userId AND SK BETWEEN :startDate AND :endDate',
  ExpressionAttributeValues: {
    ':userId': 'USER#123',
    ':startDate': 'ORDER#2024-01-01',
    ':endDate': 'ORDER#2024-12-31'
  }
}
```

### 3.3 ステータス別注文取得（GSI使用）
```javascript
{
  TableName: 'Orders',
  IndexName: 'GSI1',
  KeyConditionExpression: 'GSI1PK = :status',
  ExpressionAttributeValues: {
    ':status': 'ORDER#COMPLETED'
  }
}
```

## 4. 設計のベストプラクティス

### 4.1 キー設計のポイント
* パーティションキーにはデータの主要な識別子を使用
* ソートキーには時系列データや範囲検索が必要な項目を使用
* GSIは頻繁なアクセスパターンに合わせて設計

### 4.2 データモデリングの注意点
* 単一テーブルデザインを採用し、関連データを1つのテーブルに格納
* 検索パターンを事前に定義し、それに合わせたインデックスを設計
* 属性名は明確で理解しやすい命名規則を使用

## 5. 拡張検討ポイント

### 5.1 追加可能な機能
* 製品カテゴリによる検索（新しいGSIの追加）
* 注文金額による範囲検索
* 配送ステータスの追跡機能

### 5.2 パフォーマンス最適化
* ホットパーティションの回避
* バッチ処理の実装
* スキャンオペレーションの最小化

## 6. 実装時の注意点

### 6.1 エラーハンドリング
```javascript
try {
  const result = await dynamodb.query(params).promise();
  console.log('Query successful:', result);
} catch (error) {
  console.error('Error executing query:', error);
}
```

### 6.2 コスト最適化
* 必要な属性のみを取得するようProjectionExpressionを使用
* 適切なキャパシティユニットの設定
* クエリの効率化によるRead/Write容量の最適化

このデザインパターンは基本的な注文管理システムを想定していますが、ビジネス要件に応じて適宜カスタマイズすることができます。特に重要なのは、アクセスパターンを事前に明確化し、それに合わせたインデックス設計を行うことです。
