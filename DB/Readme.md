
---

## **ベストプラクティス（MySQL / PostgreSQL）**

### 1. インデックス設計

* **MySQL**

  * InnoDBでは主キーがクラスタ化インデックスになるため、頻繁に検索するカラムは主キーやセカンダリインデックスで最適化
  * `EXPLAIN` で `Using index` / `Using where` の有無を確認
* **PostgreSQL**

  * `BTREE`以外にも`GIN`/`GiST`/`BRIN`など用途に応じたインデックスを選択
  * 部分インデックス（`WHERE`条件付き）や式インデックスを活用

---

### 2. 実行計画の活用

* **MySQL**

  * `EXPLAIN FORMAT=JSON` で詳細な実行計画を確認
  * インデックス利用状況や`rows`見積もりが実態とズレていないか検証
* **PostgreSQL**

  * `EXPLAIN (ANALYZE, BUFFERS)`で実際の実行時間・I/O・行数を確認
  * `Seq Scan`（全表スキャン）が必要なケースかどうか判断

---

### 3. データアクセス最適化

* 必要なカラムだけSELECT（`SELECT *`禁止）
* ページネーション時はOFFSETより`seek method`（`WHERE id > ? LIMIT N`）を優先
* JOINは必要なテーブルだけに限定し、事前に集約してからJOINすることも検討

---

### 4. 統計情報の更新

* **MySQL**

  * InnoDBは自動更新だが、古いMySQLでは`ANALYZE TABLE`で統計情報更新
* **PostgreSQL**

  * 大量データ変更後は`ANALYZE`または`VACUUM ANALYZE`で最新化
  * autovacuumのパラメータ調整（`autovacuum_vacuum_scale_factor`など）

---

### 5. トランザクション管理

* できるだけ短時間でコミット
* 長時間トランザクションでロックを保持しない
* PostgreSQLでは`idle in transaction`状態を放置しない（VACUUMが止まる）

---

### 6. 大量データ処理

* **MySQL**

  * `INSERT ... VALUES (...)`をまとめる
  * MyISAM時代の`LOAD DATA INFILE`よりInnoDBは`INSERT`バッチ推奨
* **PostgreSQL**

  * `COPY`コマンドで高速ロード
  * 大量UPDATEは一括ではなくバッチ分割

---

### 7. キャッシュ活用

* Redis/Memcachedでホットデータをキャッシュ
* PostgreSQLではマテリアライズドビューを定期更新
* MySQLでは一時テーブルやサマリーテーブルで集計済データを保持

---

### 8. パーティショニング

* MySQL 8.0: RANGE/LISTパーティション活用（ただし設計ミスで逆効果あり）
* PostgreSQL 11+: ネイティブパーティショニングで時系列データを分割

---

## **アンチパターン（MySQL / PostgreSQL）**

1. \*\*SELECT \*\*\* の多用

   * インデックスが使われずI/O増大
   * ネットワーク転送量増加

2. **インデックス乱立**

   * INSERT/UPDATE/DELETEが遅くなる
   * PostgreSQLではVACUUM対象も増加

3. **実行計画を無視してクエリ修正**

   * 想定と違うJOIN順やスキャン方法になっているのを見逃す

4. **古い統計情報の放置**

   * PostgreSQLではプランナーが誤った実行計画を選択
   * MySQLでは`rows`推定がズレて最適化されない

5. **長時間ロック**

   * MySQL: 大量更新でInnoDB行ロックが競合
   * PostgreSQL: `idle in transaction`でVACUUMが進まず膨張

6. **過剰JOIN**

   * 不要なテーブルをJOINしてクエリが複雑化・遅延

7. **キャッシュ未活用**

   * 毎回同じ重い集計を実行しDB負荷を増大

8. **全件スキャン放置**

   * インデックス不足や条件ミスマッチで`Seq Scan`/`Full Table Scan`が頻発

---

これをベストプラクティスとアンチパターンを**対比表**にすれば、MySQL/PostgreSQLの運用現場ですぐに使えるチェックリストにできます。
希望があれば図解つきで整理します。
