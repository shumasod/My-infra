# 忍者キャラクターシステム設計解説書

## 1. システム概要

本システムは、忍者をテーマにしたキャラクター管理システムです。忍者のステータス、スキル、属性、装備品を包括的に管理し、キャラクターの成長や戦闘力計算を実現します。Haskellの純粋関数型プログラミングパラダイムに基づいて設計されており、データの不変性と型安全性を重視しています。

## 2. データモデル

### 2.1 コアデータ型

#### 2.1.1 忍者（Ninja）

```haskell
data Ninja = Ninja {
    ninjaName :: String,       -- 忍者の名前
    level :: Int,              -- レベル
    chakra :: Int,             -- チャクラ量
    health :: Int,             -- 体力
    skills :: Map.Map SkillName SkillLevel,  -- スキルマップ
    elements :: [Element],     -- 属性リスト
    equipment :: [Equipment]   -- 装備リスト
}
```

忍者の基本情報と能力を表すデータ型です。名前、レベル、チャクラ、体力などの基本ステータスに加え、スキル、属性、装備品を管理します。

#### 2.1.2 属性（Element）

```haskell
data Element = Fire | Water | Earth | Wind | Lightning
```

五大属性（火・水・土・風・雷）を表す代数データ型です。各忍者は複数の属性を習得できます。

#### 2.1.3 装備品（Equipment）

```haskell
data Equipment = Equipment {
    equipName :: String,          -- 装備名
    equipType :: EquipmentType,   -- 装備タイプ
    power :: Int,                 -- 威力
    requirements :: [Requirement] -- 装備要件
}
```

忍者が装備できるアイテムを表すデータ型です。装備には名前、タイプ、威力に加え、装備するために必要なスキル要件があります。

### 2.2 型エイリアス

```haskell
type SkillName = String
type SkillLevel = Int
type Requirement = (SkillName, SkillLevel)
```

コードの可読性と意図の明確化のために使用される型エイリアスです。

## 3. 主要機能

### 3.1 忍者作成と成長

#### 3.1.1 忍者作成（createNinja）

```haskell
createNinja :: String -> Maybe Ninja
```

名前を指定して新しい忍者を作成します。名前のバリデーションを行い、有効な場合は初期ステータスの忍者を返します。無効な場合は `Nothing` を返します。

#### 3.1.2 レベルアップ（levelUp）

```haskell
levelUp :: Ninja -> Ninja
```

忍者のレベルを1上げ、関連するステータス（チャクラ、体力、スキル）も向上させます。すべての値は設定された上限を超えないように制限されます。

#### 3.1.3 スキル習得（learnSkill）

```haskell
learnSkill :: SkillName -> Ninja -> Ninja
```

忍者に新しいスキルを習得させるか、既存のスキルレベルを向上させます。スキルレベルは最大値を超えないように制限されます。

### 3.2 属性と装備

#### 3.2.1 属性追加（addElement）

```haskell
addElement :: Element -> Ninja -> Ninja
```

忍者に新しい忍術属性を追加します。既に持っている属性の場合は変更を行いません。

#### 3.2.2 装備管理（equipItem）

```haskell
equipItem :: Equipment -> Ninja -> Maybe Ninja
```

忍者に装備品を装着します。装備要件を満たしている場合のみ装備可能です。同じタイプの装備がある場合は新しい装備に置き換えられます。

### 3.3 評価と表示

#### 3.3.1 戦闘力計算（calculatePower）

```haskell
calculatePower :: Ninja -> Int
```

忍者の総合的な戦闘力を計算します。基本ステータス、スキルレベル、装備の威力、属性ボーナスを考慮した計算式を用います。

#### 3.3.2 情報表示（displayNinjaInfo）

```haskell
displayNinjaInfo :: Ninja -> String
```

忍者の詳細情報を読みやすい形式で表示します。すべてのステータス、スキル、属性、装備を含む包括的な情報を提供します。

## 4. 設計の特徴

### 4.1 純粋関数型アプローチ

- **不変データ構造**: すべてのデータ操作は新しい値を返し、元のデータは変更されません
- **副作用の最小化**: IO関数とそれ以外の純粋関数を明確に分離しています
- **Maybe型による安全な操作**: 失敗する可能性のある操作は `Maybe` 型を返し、明示的なエラーハンドリングを強制します

### 4.2 モジュール化された設計

- **関連機能のグループ化**: 関連する機能は論理的にグループ化されています
- **明確なインターフェース**: モジュールは明示的なエクスポートリストを持ち、外部からの使用方法を明確にしています
- **ドキュメンテーション**: 各関数と型には詳細なドキュメントが付与されています

### 4.3 バリデーションと安全性

- **入力値の検証**: 名前、パワー値など、入力値には適切なバリデーションが施されています
- **上限の適用**: レベル、チャクラ、体力、スキルレベルには上限が設定されています
- **要件チェック**: 装備品の装着時には要件チェックが行われます

## 5. 拡張性

システムは以下のような拡張が容易に行えるように設計されています：

### 5.1 戦闘システム
- 忍術の実装と効果計算
- ダメージ計算と戦闘シミュレーション
- 状態異常と特殊効果

### 5.2 成長システム
- 経験値獲得と自動レベルアップ
- スキルツリーと専門化
- 特殊能力と忍術の習得

### 5.3 社会システム
- 忍者村と所属関係
- ランクと任務システム
- チーム編成と連携技

### 5.4 アイテムシステム
- 巻物と消費アイテム
- 装備品の強化と進化
- アイテム合成と作成

## 6. 実装例

以下は、システムの基本的な使用例です：

```haskell
main :: IO ()
main = do
    -- 新しい忍者を作成
    case createNinja "Kakashi" of
        Nothing -> putStrLn "無効な名前です"
        Just ninja -> do
            -- 成長処理
            let grown = levelUp $ levelUp $ learnSkill "Chidori" ninja
            
            -- 属性追加
            element <- randomElement
            let elemental = addElement element grown
            
            -- 装備追加
            case createAdvancedEquipment "Sharingan Eye" Accessory 25 [("Genjutsu", 5)] of
                Nothing -> putStrLn "無効な装備です"
                Just sharingan -> case equipItem sharingan elemental of
                    Nothing -> putStrLn "装備要件を満たしていません"
                    Just equipped -> do
                        -- 最終情報表示
                        putStrLn $ displayNinjaInfo equipped
```

## 7. 今後の発展方向

このシステムは、以下の方向に発展させることができます：

1. **対話型インターフェース**: コマンドラインやGUIによる対話型インターフェースの追加
2. **永続化**: 忍者データの保存と読み込み機能
3. **複数忍者の管理**: チームや村単位での忍者管理
4. **イベントシステム**: ストーリーイベントや任務の実装
5. **バランス調整**: ゲームバランスの微調整と拡張

## 8. まとめ

本忍者キャラクターシステムは、Haskellの強力な型システムと純粋関数型プログラミングの利点を活かした設計となっています。データの一貫性と安全性を保ちながら、拡張性の高いシステムアーキテクチャを実現しています。今後のゲーム開発やシミュレーションシステムの基盤として活用できるでしょう。
