# Haskell 忍者キャラクターシステム解説

## 1. データ型の定義

### 1.1 忍者（Ninja）データ型
```haskell
data Ninja = Ninja {
    ninjaName :: String,  -- 忍者の名前
    level :: Int,         -- レベル
    chakra :: Int,        -- チャクラ量
    health :: Int,        -- 体力
    skills :: Map.Map String Int,  -- スキルマップ
    elements :: [Element],         -- 属性リスト
    equipment :: [Equipment]       -- 装備リスト
}
```

忍者の基本的な属性を表現するレコード型です。各フィールドは以下の情報を保持します：
- `ninjaName`: 忍者の名前（文字列）
- `level`: 現在のレベル（整数）
- `chakra`: チャクラ量（整数）
- `health`: 体力値（整数）
- `skills`: スキル名とレベルのマッピング
- `elements`: 習得した属性のリスト
- `equipment`: 装備しているアイテムのリスト

### 1.2 属性（Element）データ型
```haskell
data Element = Fire | Water | Earth | Wind | Lightning
```

五大忍術属性を表現する代数データ型です：
- `Fire`: 火遁
- `Water`: 水遁
- `Earth`: 土遁
- `Wind`: 風遁
- `Lightning`: 雷遁

### 1.3 装備品（Equipment）データ型
```haskell
data Equipment = Equipment {
    equipName :: String,
    equipType :: EquipmentType,
    power :: Int,
    requirements :: [(String, Int)]
}
```

装備品の情報を管理するレコード型：
- `equipName`: 装備品の名前
- `equipType`: 装備品の種類（武器/防具/アクセサリー）
- `power`: 装備品の基本性能値
- `requirements`: 装備要件（必要スキルと必要レベル）

## 2. 主要な関数

### 2.1 忍者作成
```haskell
createNinja :: String -> Ninja
```
新しい忍者を作成する関数です。初期値として：
- レベル1
- チャクラ100
- 体力100
- 基本スキル（体術、忍術、幻術）をレベル1で設定

### 2.2 レベルアップ
```haskell
levelUp :: Ninja -> Ninja
```
忍者のレベルアップを処理する関数：
- レベルが1上昇
- チャクラが10増加
- 体力が15増加
- 全スキルが1レベル上昇

### 2.3 スキル習得
```haskell
learnSkill :: String -> Ninja -> Ninja
```
新しいスキルを習得または既存スキルを強化する関数です。

### 2.4 装備管理
```haskell
equipItem :: Equipment -> Ninja -> Maybe Ninja
```
装備品の装着を試みる関数：
- 装備要件を満たしている場合のみ装備可能
- `Maybe`型を使用して装備の成功/失敗を表現

### 2.5 戦闘力計算
```haskell
calculatePower :: Ninja -> Int
```
忍者の総合的な戦闘力を計算する関数：
- 基本ステータス（レベル×10 + チャクラ）
- スキルレベルの合計
- 装備品の性能値合計
- 属性ボーナス（属性数×15）

## 3. 補助関数

### 3.1 ランダム属性生成
```haskell
randomElement :: IO Element
```
ランダムな忍術属性を生成するIO関数です。

### 3.2 情報表示
```haskell
displayNinjaInfo :: Ninja -> String
```
忍者の詳細情報を文字列として整形する関数です。

## 4. 使用例

```haskell
main :: IO ()
main = do
    -- 忍者作成
    let ninja = createNinja "Naruto"
    
    -- 成長処理
    let trainedNinja = levelUp $ learnSkill "Rasengan" ninja
    
    -- 属性追加
    element <- randomElement
    let elementalNinja = addElement element trainedNinja
    
    -- 情報表示
    putStrLn $ displayNinjaInfo elementalNinja
```

## 5. 設計上のポイント

1. **純粋関数型設計**
   - 状態の変更は新しい値を返すことで表現
   - 副作用を最小限に抑制

2. **型安全性**
   - 適切なデータ型の使用
   - `Maybe`型による安全な値の処理

3. **拡張性**
   - モジュール化された構造
   - 新機能追加が容易な設計

4. **データの不変性**
   - レコード更新構文による安全な状態更新
   - 元のデータを変更しない関数設計

## 6. 今後の拡張可能性

1. **戦闘システム**
   - 忍術の実装
   - ダメージ計算
   - 状態異常の追加

2. **成長システム**
   - 経験値システム
   - スキルツリー
   - 特殊能力

3. **ミッションシステム**
   - クエスト機能
   - 報酬システム
   - 難易度設定

4. **チーム編成**
   - パーティシステム
   - 連携技
   - チーム効果

5. **アイテムシステム**
   - アイテム作成
   - 強化システム
   - トレード機能

これらの拡張は、既存のコードベースを維持しながら段階的に実装可能です。
