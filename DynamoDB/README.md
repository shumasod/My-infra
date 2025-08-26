# DynamoDB 注文管理システム - 完全ガイド

このドキュメントでは、AWS SDK v3とモダンなJavaScript実装を使用した、本格的な注文管理システムのDynamoDB設計と実装について詳しく解説します。

## 目次

1. [システム概要](#1-システム概要)
1. [テーブル設計](#2-テーブル設計)
1. [データモデリング](#3-データモデリング)
1. [クエリパターン](#4-クエリパターン)
1. [実装詳細](#5-実装詳細)
1. [運用とモニタリング](#6-運用とモニタリング)
1. [ベストプラクティス](#7-ベストプラクティス)

-----

## 1. システム概要

### 1.1 主要機能

- 注文の作成・更新・取得
- ユーザー別注文履歴管理
- ステータス別注文検索
- 日付範囲での注文絞り込み
- 統計情報とレポート生成
- バッチ処理による一括操作

### 1.2 技術スタック

- **AWS SDK**: v3 (最新版)
- **DynamoDB**: シングルテーブル設計
- **Node.js**: ES2022+
- **エラーハンドリング**: 指数バックオフ付きリトライ
- **セキュリティ**: Point-in-Time Recovery, 暗号化

### 1.3 主要な改善点

- **堅牢なバリデーション**: 詳細なエラーメッセージと型チェック
- **複数GSI設計**: 検索性能の最適化
- **金額計算の精度**: 小数点誤差の回避
- **包括的エラーハンドリング**: 本番環境対応
- **統計機能**: ビジネス分析サポート

-----

## 2. テーブル設計

### 2.1 基本テーブル構造

```javascript
const OrderTableDefinition = {
  TableName: 'Orders',
  KeySchema: [
    { AttributeName: 'PK', KeyType: 'HASH' },   // ユーザーベースの分散
    { AttributeName: 'SK', KeyType: 'RANGE' }   // 日付+注文ID でソート
  ],
  AttributeDefinitions: [
    { AttributeName: 'PK', AttributeType: 'S' },      // USER#{userId}
    { AttributeName: 'SK', AttributeType: 'S' },      // ORDER#{date}#{orderId}
    { AttributeName: 'GSI1PK', AttributeType: 'S' },  // STATUS#{status}
    { AttributeName: 'GSI1SK', AttributeType: 'S' },  // {date}#{orderId}
    { AttributeName: 'GSI2PK', AttributeType: 'S' },  // DATE#{date}
    { AttributeName: 'GSI2SK', AttributeType: 'S' }   // {status}#{orderId}
  ]
}
```

### 2.2 グローバルセカンダリインデックス (GSI)

#### GSI1: ステータス別検索用

```javascript
{
  IndexName: 'GSI1-Status-Date',
  KeySchema: [
    { AttributeName: 'GSI1PK', KeyType: 'HASH' },   // STATUS#{status}
    { AttributeName: 'GSI1SK', KeyType: 'RANGE' }   // {date}#{orderId}
  ],
  // 用途: 特定ステータスの注文を日付順で取得
  // 例: 保留中の注文を古い順に処理
}
```

#### GSI2: 日付別検索用

```javascript
{
  IndexName: 'GSI2-Date-Status',
  KeySchema: [
    { AttributeName: 'GSI2PK', KeyType: 'HASH' },   // DATE#{date}
    { AttributeName: 'GSI2SK', KeyType: 'RANGE' }   // {status}#{orderId}
  ],
  // 用途: 特定日の注文をステータス別に取得
  // 例: 2024-03-08の注文を完了済み順に表示
}
```

### 2.3 テーブル設定の強化

```javascript
{
  BillingMode: 'PAY_PER_REQUEST',              // スケーラブルな料金体系
  PointInTimeRecoverySpecification: {
    PointInTimeRecoveryEnabled: true           // データ保護
  },
  SSESpecification: {
    SSEEnabled: true                           // 暗号化
  },
  Tags: [
    { Key: 'Environment', Value: 'production' },
    { Key: 'Project', Value: 'OrderManagement' },
    { Key: 'CostCenter', Value: 'Engineering' }
  ]
}
```

-----

## 3. データモデリング

### 3.1 注文アイテムの完全な構造

```javascript
{
  // プライマリキー
  PK: 'USER#user123',
  SK: 'ORDER#2024-03-08#550e8400-e29b-41d4-a716-446655440000',
  
  // 基本情報
  orderId: '550e8400-e29b-41d4-a716-446655440000',
  userId: 'user123',
  orderDate: '2024-03-08',
  status: 'CONFIRMED',
  
  // タイムスタンプ
  createdAt: '2024-03-08T10:30:00.000Z',
  updatedAt: '2024-03-08T11:15:00.000Z',
  
  // 金額情報（精密計算）
  subtotal: 3500.00,      // 商品合計
  tax: 350.00,            // 税額
  taxRate: 0.1,           // 税率 (10%)
  total: 3850.00,         // 総額
  currency: 'JPY',
  
  // 注文アイテム詳細
  items: [
    {
      productId: 'P001',
      productName: 'Wireless Headphones',
      quantity: 2,
      unitPrice: 1500.00,
      totalPrice: 3000.00,
      sku: 'WH-1500-BLK',
      category: 'Electronics'
    },
    {
      productId: 'P002',
      productName: 'Phone Case',
      quantity: 1,
      unitPrice: 500.00,
      totalPrice: 500.00,
      sku: 'PC-500-RED',
      category: 'Accessories'
    }
  ],
  
  // 配送・請求情報
  shippingAddress: {
    name: 'John Doe',
    address: '123 Shibuya Street',
    city: 'Tokyo',
    postalCode: '150-0002',
    country: 'Japan'
  },
  billingAddress: { /* 同様の構造 */ },
  shippingMethod: 'STANDARD',
  
  // GSI用キー
  GSI1PK: 'STATUS#CONFIRMED',
  GSI1SK: '2024-03-08#550e8400-e29b-41d4-a716-446655440000',
  GSI2PK: 'DATE#2024-03-08',
  GSI2SK: 'CONFIRMED#550e8400-e29b-41d4-a716-446655440000',
  
  // メタデータ
  version: 1,              // 楽観的排他制御
  source: 'mobile_app',    // 注文元
  notes: 'Gift wrapping requested'
}
```

### 3.2 注文ステータスの定義

```javascript
const ORDER_STATUS = {
  PENDING: 'PENDING',           // 保留中
  CONFIRMED: 'CONFIRMED',       // 確認済み
  PROCESSING: 'PROCESSING',     // 処理中
  SHIPPED: 'SHIPPED',           // 発送済み
  DELIVERED: 'DELIVERED',       // 配達完了
  CANCELLED: 'CANCELLED',       // キャンセル
  REFUNDED: 'REFUNDED'          // 返金済み
}
```

### 3.3 バリデーション仕様

```javascript
function validateOrder(order) {
  const errors = [];
  
  // 必須フィールド検証
  if (!order.userId || typeof order.userId !== 'string') {
    errors.push('UserId is required and must be a string');
  }
  
  if (!/^\d{4}-\d{2}-\d{2}$/.test(order.orderDate)) {
    errors.push('OrderDate must be in YYYY-MM-DD format');
  }
  
  // ビジネスルール検証
  if (!Array.isArray(order.items) || order.items.length === 0) {
    errors.push('Items must be a non-empty array');
  }
  
  // 数値精度検証
  order.items?.forEach((item, index) => {
    if (typeof item.quantity !== 'number' || !Number.isInteger(item.quantity) || item.quantity <= 0) {
      errors.push(`Item[${index}]: quantity must be a positive integer`);
    }
    
    if (typeof item.price !== 'number' || item.price < 0) {
      errors.push(`Item[${index}]: price must be non-negative`);
    }
  });
  
  return { isValid: errors.length === 0, errors };
}
```

-----

## 4. クエリパターン

### 4.1 主要なアクセスパターン

|パターン    |使用頻度|重要度|実装方法     |
|--------|----|---|---------|
|ユーザー注文履歴|高   |高  |プライマリテーブル|
|ステータス別検索|中   |高  |GSI1     |
|日付別検索   |中   |中  |GSI2     |
|個別注文取得  |高   |高  |Get操作    |
|統計情報    |低   |中  |複合クエリ    |

### 4.2 実装例

#### 4.2.1 ユーザーの注文履歴取得

```javascript
async function getUserOrders(userId, options = {}) {
  const {
    limit = 50,
    ascending = false,
    startDate,
    endDate,
    status
  } = options;
  
  let keyCondition = 'PK = :userId';
  const expressionValues = { ':userId': `USER#${userId}` };
  
  // 日付範囲の指定
  if (startDate && endDate) {
    keyCondition += ' AND SK BETWEEN :startDate AND :endDate';
    expressionValues[':startDate'] = `ORDER#${startDate}`;
    expressionValues[':endDate'] = `ORDER#${endDate}#\uFFFF`;
  }
  
  const params = {
    TableName: ORDERS_TABLE,
    KeyConditionExpression: keyCondition,
    ExpressionAttributeValues: expressionValues,
    ScanIndexForward: ascending,
    Limit: limit
  };
  
  // ステータスフィルター（効率的なFilterExpression）
  if (status) {
    params.FilterExpression = '#status = :status';
    params.ExpressionAttributeNames = { '#status': 'status' };
    params.ExpressionAttributeValues[':status'] = status;
  }
  
  const command = new QueryCommand(params);
  return await docClient.send(command);
}
```

#### 4.2.2 ステータス別注文検索（GSI1使用）

```javascript
async function getOrdersByStatus(status, options = {}) {
  const params = {
    TableName: ORDERS_TABLE,
    IndexName: 'GSI1-Status-Date',
    KeyConditionExpression: 'GSI1PK = :status',
    ExpressionAttributeValues: {
      ':status': `STATUS#${status}`
    },
    ScanIndexForward: options.ascending || false,
    Limit: options.limit || 50
  };
  
  // 日付範囲フィルター
  if (options.startDate && options.endDate) {
    params.KeyConditionExpression += ' AND GSI1SK BETWEEN :startDate AND :endDate';
    params.ExpressionAttributeValues[':startDate'] = `${options.startDate}#`;
    params.ExpressionAttributeValues[':endDate'] = `${options.endDate}#\uFFFF`;
  }
  
  const command = new QueryCommand(params);
  return await docClient.send(command);
}
```

#### 4.2.3 トランザクション処理による注文更新

```javascript
async function updateOrderWithInventory(userId, orderId, orderDate, newStatus) {
  const transactItems = [
    {
      Update: {
        TableName: ORDERS_TABLE,
        Key: {
          PK: `USER#${userId}`,
          SK: `ORDER#${orderDate}#${orderId}`
        },
        UpdateExpression: `
          SET #status = :newStatus, 
              updatedAt = :now, 
              version = version + :inc,
              GSI1PK = :newGSI1PK,
              GSI2SK = :newGSI2SK
        `,
        ExpressionAttributeNames: { '#status': 'status' },
        ExpressionAttributeValues: {
          ':newStatus': newStatus,
          ':now': new Date().toISOString(),
          ':inc': 1,
          ':newGSI1PK': `STATUS#${newStatus}`,
          ':newGSI2SK': `${newStatus}#${orderId}`
        },
        ConditionExpression: 'attribute_exists(PK)'
      }
    }
    // 必要に応じて在庫テーブルの更新も追加
  ];
  
  const command = new TransactWriteCommand({ TransactItems: transactItems });
  return await docClient.send(command);
}
```

-----

## 5. 実装詳細

### 5.1 エラーハンドリング戦略

```javascript
async function executeWithRetry(operation, operationName) {
  const maxRetries = 3;
  let lastError;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      
      // リトライしない条件
      if (error.name === 'ValidationException' || 
          error.name === 'ConditionalCheckFailedException' ||
          attempt === maxRetries) {
        break;
      }
      
      // 指数バックオフ（最大5秒）
      const delay = Math.min(1000 * Math.pow(2, attempt - 1), 5000);
      await new Promise(resolve => setTimeout(resolve, delay));
      
      console.warn(`${operationName} attempt ${attempt} failed, retrying in ${delay}ms`);
    }
  }
  
  console.error(`${operationName} failed after ${maxRetries} attempts:`, lastError);
  throw lastError;
}
```

### 5.2 統計情報の生成

```javascript
async function getOrderStatistics(userId = null, options = {}) {
  const { startDate, endDate } = options;
  
  // データ取得
  let orders;
  if (userId) {
    orders = await getUserOrders(userId, { startDate, endDate, limit: 1000 });
  } else {
    orders = await getOrdersByDate(startDate, { limit: 1000 });
  }
  
  const items = orders.Items || [];
  
  // 統計計算
  const stats = {
    totalOrders: items.length,
    totalAmount: items.reduce((sum, order) => sum + (order.total || 0), 0),
    averageOrderValue: 0,
    statusBreakdown: {},
    topProducts: {},
    trends: {
      dailyOrders: {},
      dailyRevenue: {}
    }
  };
  
  // ステータス別集計
  items.forEach(order => {
    const status = order.status || 'UNKNOWN';
    stats.statusBreakdown[status] = (stats.statusBreakdown[status] || 0) + 1;
    
    // 日別トレンド
    const date = order.orderDate;
    stats.trends.dailyOrders[date] = (stats.trends.dailyOrders[date] || 0) + 1;
    stats.trends.dailyRevenue[date] = (stats.trends.dailyRevenue[date] || 0) + order.total;
    
    // 商品別集計
    order.items?.forEach(item => {
      const productId = item.productId;
      if (!stats.topProducts[productId]) {
        stats.topProducts[productId] = {
          quantity: 0,
          revenue: 0,
          productName: item.productName || productId
        };
      }
      stats.topProducts[productId].quantity += item.quantity;
      stats.topProducts[productId].revenue += item.totalPrice || 0;
    });
  });
  
  stats.averageOrderValue = stats.totalOrders > 0 
    ? Math.round((stats.totalAmount / stats.totalOrders) * 100) / 100 
    : 0;
  
  return stats;
}
```

### 5.3 バッチ処理の最適化

```javascript
async function batchSaveOrders(orderDataList) {
  const batchSize = 25; // DynamoDB制限
  const results = [];
  
  for (let i = 0; i < orderDataList.length; i += batchSize) {
    const batch = orderDataList.slice(i, i + batchSize);
    
    const params = {
      RequestItems: {
        [ORDERS_TABLE]: batch.map(orderData => ({
          PutRequest: { Item: createOrderItem(orderData) }
        }))
      }
    };
    
    let attempt = 0;
    let unprocessedItems = params.RequestItems;
    
    // 未処理アイテムの処理
    while (unprocessedItems && Object.keys(unprocessedItems).length > 0 && attempt < 3) {
      const command = new BatchWriteCommand({ RequestItems: unprocessedItems });
      const result = await docClient.send(command);
      
      unprocessedItems = result.UnprocessedItems;
      attempt++;
      
      if (unprocessedItems && Object.keys(unprocessedItems).length > 0) {
        // 指数バックオフ
        await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, attempt)));
      }
    }
    
    results.push({ batchIndex: Math.floor(i / batchSize), processed: batch.length });
  }
  
  return results;
}
```

-----

## 6. 運用とモニタリング

### 6.1 CloudWatchメトリクス監視

```javascript
// 主要な監視メトリクス
const MONITORING_METRICS = {
  // パフォーマンス
  'AWS/DynamoDB/ConsumedReadCapacityUnits': '読み取り容量使用量',
  'AWS/DynamoDB/ConsumedWriteCapacityUnits': '書き込み容量使用量',
  'AWS/DynamoDB/SuccessfulRequestLatency': 'レスポンス時間',
  
  // エラー
  'AWS/DynamoDB/ThrottledRequests': 'スロットリング発生数',
  'AWS/DynamoDB/SystemErrors': 'システムエラー数',
  'AWS/DynamoDB/UserErrors': 'ユーザーエラー数',
  
  // ストレージ
  'AWS/DynamoDB/TableSizeBytes': 'テーブルサイズ',
  'AWS/DynamoDB/ItemCount': 'アイテム数'
};
```

### 6.2 アラート設定例

```yaml
# CloudWatch Alarms (YAML形式での設定例)
HighLatencyAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: DynamoDB-Orders-HighLatency
    MetricName: SuccessfulRequestLatency
    Namespace: AWS/DynamoDB
    Statistic: Average
    Period: 300
    EvaluationPeriods: 2
    Threshold: 100  # 100ms
    ComparisonOperator: GreaterThanThreshold
    
ThrottlingAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: DynamoDB-Orders-Throttling
    MetricName: ThrottledRequests
    Namespace: AWS/DynamoDB
    Statistic: Sum
    Period: 300
    EvaluationPeriods: 1
    Threshold: 0
    ComparisonOperator: GreaterThanThreshold
```

### 6.3 ログ分析とトレーシング

```javascript
// 構造化ログの実装例
function logDynamoDBOperation(operation, params, result, duration) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    operation,
    tableName: params.TableName,
    indexName: params.IndexName,
    duration: `${duration}ms`,
    itemCount: result.Items?.length || 0,
    scannedCount: result.ScannedCount,
    consumedCapacity: result.ConsumedCapacity,
    lastEvaluatedKey: !!result.LastEvaluatedKey,
    requestId: result.$metadata?.requestId
  };
  
  console.log(JSON.stringify(logEntry));
}

// 使用例
const startTime = Date.now();
const result = await docClient.send(command);
const duration = Date.now() - startTime;
logDynamoDBOperation('Query', params, result, duration);
```

-----

## 7. ベストプラクティス

### 7.1 パフォーマンス最適化

#### ホットパーティション対策

```javascript
// パーティション分散の改善例
function createDistributedKey(userId) {
  // ユーザーIDのハッシュを使用してサフィックスを生成
  const hash = crypto.createHash('md5').update(userId).digest('hex');
  const suffix = parseInt(hash.substring(0, 2), 16) % 10; // 0-9
  return `USER#${userId}#${suffix}`;
}

// 検索時は全てのサフィックスを並列クエリ
async function getDistributedUserOrders(userId, options = {}) {
  const promises = [];
  
  for (let suffix = 0; suffix < 10; suffix++) {
    const params = {
      TableName: ORDERS_TABLE,
      KeyConditionExpression: 'PK = :pk',
      ExpressionAttributeValues: {
        ':pk': `USER#${userId}#${suffix}`
      },
      ...options
    };
    
    promises.push(docClient.send(new QueryCommand(params)));
  }
  
  const results = await Promise.all(promises);
  
  // 結果をマージして日付順にソート
  const allItems = results.flatMap(result => result.Items || []);
  return allItems.sort((a, b) => new Date(b.orderDate) - new Date(a.orderDate));
}
```

#### クエリの最適化

```javascript
// プロジェクション式による効率化
const PROJECTION_EXPRESSIONS = {
  LIST: 'orderId, orderDate, #status, total, items[0].productName',
  DETAIL: 'orderId, orderDate, #status, total, items, shippingAddress, createdAt',
  SUMMARY: 'orderId, total, #status'
};

// 必要な属性のみを取得
async function getUserOrdersSummary(userId) {
  const params = {
    TableName: ORDERS_TABLE,
    KeyConditionExpression: 'PK = :userId',
    ExpressionAttributeValues: { ':userId': `USER#${userId}` },
    ProjectionExpression: PROJECTION_EXPRESSIONS.SUMMARY,
    ExpressionAttributeNames: { '#status': 'status' }
  };
  
  return await docClient.send(new QueryCommand(params));
}
```

### 7.2 データ整合性の確保

#### 楽観的排他制御

```javascript
async function updateOrderWithOptimisticLocking(userId, orderId, orderDate, updates) {
  // 現在のバージョンを取得
  const current = await getOrder(userId, orderId, orderDate);
  if (!current) {
    throw new Error('Order not found');
  }
  
  const params = {
    TableName: ORDERS_TABLE,
    Key: {
      PK: `USER#${userId}`,
      SK: `ORDER#${orderDate}#${orderId}`
    },
    UpdateExpression: 'SET version = version + :inc, updatedAt = :now',
    ExpressionAttributeValues: {
      ':inc': 1,
      ':now': new Date().toISOString(),
      ':expectedVersion': current.version
    },
    ConditionExpression: 'version = :expectedVersion'
  };
  
  // 追加の更新フィールドを設定
  Object.entries(updates).forEach(([key, value], index) => {
    params.UpdateExpression += `, #${key} = :val${index}`;
    params.ExpressionAttributeNames = { 
      ...params.ExpressionAttributeNames,
      [`#${key}`]: key 
    };
    params.ExpressionAttributeValues[`:val${index}`] = value;
  });
  
  try {
    const command = new UpdateCommand(params);
    return await docClient.send(command);
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      throw new Error('Order was modified by another process. Please retry.');
    }
    throw error;
  }
}
```

### 7.3 コスト最適化戦略

#### TTLによる自動データ削除

```javascript
function addTTLToOrder(orderItem, retentionDays = 2555) { // 約7年
  const ttlTimestamp = Math.floor(Date.now() / 1000) + (retentionDays * 24 * 60 * 60);
  return {
    ...orderItem,
    ttl: ttlTimestamp  // TTL属性
  };
}

// 古いデータのアーカイブ処理
async function archiveOldOrders() {
  const cutoffDate = new Date();
  cutoffDate.setFullYear(cutoffDate.getFullYear() - 1); // 1年前
  
  // DynamoDB Streamsと組み合わせてS3にアーカイブ
  // Lambda関数で実装することが一般的
}
```

#### 読み取り頻度による戦略的設計

```javascript
// 頻繁にアクセスされる最新データ用のGSI
const RECENT_ORDERS_GSI = {
  IndexName: 'GSI-Recent-Orders',
  KeySchema: [
    { AttributeName: 'GSI3PK', KeyType: 'HASH' },  // RECENT#{date}
    { AttributeName: 'GSI3SK', KeyType: 'RANGE' }  // {timestamp}#{orderId}
  ],
  // 直近30日のデータのみにGSI属性を設定
  // TTL機能と組み合わせてインデックスサイズを制御
};

function addRecentOrdersGSI(orderItem) {
  const orderDate = new Date(orderItem.orderDate);
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  // 30日以内の注文のみGSI属性を追加
  if (orderDate >= thirtyDaysAgo) {
    return {
      ...orderItem,
      GSI3PK: `RECENT#${orderItem.orderDate}`,
      GSI3SK: `${orderItem.createdAt}#${orderItem.orderId}`
    };
  }
  
  return orderItem;
}
```

### 7.4 スケーラビリティ設計

#### マルチリージョン対応

```javascript
// リージョン間レプリケーション設定
const GLOBAL_TABLE_CONFIG = {
  TableName: 'Orders',
  GlobalTableVersion: '2019.11.21',
  ReplicationGroup: [
    { RegionName: 'us-east-1' },
    { RegionName: 'ap-northeast-1' },
    { RegionName: 'eu-west-1' }
  ]
};

// リージョン固有のクライアント設定
const clients = {
  'us-east-1': new DynamoDBClient({ region: 'us-east-1' }),
  'ap-northeast-1': new DynamoDBClient({ region: 'ap-northeast-1' }),
  'eu-west-1': new DynamoDBClient({ region: 'eu-west-1' })
};

// 最寄りリージョンへの読み取り
function getNearestRegionClient(userLocation) {
  const regionMapping = {
    'US': 'us-east-1',
    'JP': 'ap-northeast-1',
    'EU': 'eu-west-1'
  };
  
  return clients[regionMapping[userLocation]] || clients['us-east-1'];
}
```

-----

## 8. セキュリティ考慮事項

### 8.1 IAMポリシー例

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem
```