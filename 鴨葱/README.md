# AWK 完全ガイド

AWKは、テキスト処理のためのプログラミング言語およびコマンドラインユーティリティです。1977年にAlfred Aho、Peter Weinberger、Brian Kernighanによって開発され、Unix/Linuxシステムでのテキスト処理の標準ツールとして広く使用されています。

## 目次

- [特徴](#特徴)
- [基本構文](#基本構文)
- [主要機能](#主要機能)
  - [1. フィールド抽出](#1-フィールド抽出)
  - [2. パターンマッチング](#2-パターンマッチング)
  - [3. 数値計算と集計](#3-数値計算と集計)
  - [4. テキスト置換と変換](#4-テキスト置換と変換)
  - [5. レポート生成](#5-レポート生成)
  - [6. 条件分岐と制御構造](#6-条件分岐と制御構造)
  - [7. 配列操作](#7-配列操作)
  - [8. 関数の使用](#8-関数の使用)
- [実践的な使用例](#実践的な使用例)
- [組み込み変数](#組み込み変数)
- [組み込み関数](#組み込み関数)
- [ベストプラクティス](#ベストプラクティス)
- [参考資料](#参考資料)

## 特徴

- **行ベース処理**: テキストを行単位で処理
- **フィールド指向**: 区切り文字で分割されたフィールドを簡単に扱える
- **パターン-アクション**: パターンにマッチした行に対してアクションを実行
- **軽量**: シンプルで高速なテキスト処理
- **移植性**: ほぼすべてのUnix/Linuxシステムで利用可能

## 基本構文

```awk
awk 'パターン { アクション }' ファイル名
```

### 構造

```awk
BEGIN { 
    # 処理開始前に一度だけ実行
}

パターン { 
    # マッチした各行で実行
}

END { 
    # 処理終了後に一度だけ実行
}
```

### よく使うオプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `-F` | フィールド区切り文字を指定 | `awk -F: '{print $1}' file` |
| `-v` | 変数を設定 | `awk -v var=value '{print var}' file` |
| `-f` | スクリプトファイルを指定 | `awk -f script.awk file` |

## 主要機能

### 1. フィールド抽出

AWKはテキストをフィールド（区切り文字で分割された値）として扱い、簡単に抽出できます。

#### 基本的なフィールド抽出

```awk
# 第1フィールド(ユーザー名)を抽出
awk -F: '{print $1}' /etc/passwd

# 複数のフィールドを抽出（ユーザー名とUID）
awk -F: '{print $1, $3}' /etc/passwd

# 最後のフィールドを抽出
awk '{print $NF}' file.txt

# 最後から2番目のフィールドを抽出
awk '{print $(NF-1)}' file.txt
```

#### カスタム出力フォーマット

```awk
# タブ区切りで出力
awk -F: '{print $1 "\t" $3}' /etc/passwd

# フォーマット指定で整形
awk -F: '{printf "%-20s UID: %5d\n", $1, $3}' /etc/passwd
```

### 2. パターンマッチング

特定の条件にマッチする行のみを処理できます。

#### 文字列マッチング

```awk
# "root"を含む行を抽出
awk '/root/' /etc/passwd

# 特定のフィールドが"root"の行を抽出
awk -F: '$1 == "root" {print $0}' /etc/passwd

# 正規表現でマッチング（bashで始まる行）
awk '/^bash/' /etc/shells

# 特定のフィールドが正規表現にマッチ
awk -F: '$7 ~ /bash/ {print $1}' /etc/passwd
```

#### 数値比較

```awk
# UID が 1000 以上のユーザーを抽出
awk -F: '$3 >= 1000 {print $1, $3}' /etc/passwd

# 範囲指定（UID が 1000 から 2000 の間）
awk -F: '$3 >= 1000 && $3 <= 2000 {print $1, $3}' /etc/passwd

# 特定の値ではない行
awk -F: '$3 != 0 {print $1}' /etc/passwd
```

#### 論理演算

```awk
# AND条件
awk -F: '$3 >= 1000 && $7 ~ /bash/ {print $1}' /etc/passwd

# OR条件
awk -F: '$1 == "root" || $1 == "admin" {print $0}' /etc/passwd

# NOT条件
awk -F: '!($3 < 1000) {print $1}' /etc/passwd
```

### 3. 数値計算と集計

AWKは数値演算や統計処理が得意です。

#### 基本計算

```awk
# 1から10までの合計を計算
awk 'BEGIN {sum=0; for(i=1; i<=10; i++) sum+=i; print sum}'

# 1から100までの平均を計算
awk 'BEGIN {
    sum=0; 
    for(i=1; i<=100; i++) sum+=i; 
    print "平均:", sum/100
}'
```

#### ファイルからの集計

```awk
# ファイルの行数をカウント
awk 'END {print NR}' file.txt

# 特定のフィールドの合計を計算
awk '{sum += $3} END {print "合計:", sum}' sales.txt

# 平均を計算
awk '{sum += $1; count++} END {print "平均:", sum/count}' numbers.txt

# 最大値と最小値を見つける
awk 'BEGIN {max=-999999; min=999999} 
     {if($1 > max) max=$1; if($1 < min) min=$1} 
     END {print "最大:", max, "最小:", min}' numbers.txt
```

#### 統計処理

```awk
# 標準偏差の計算
awk '{
    sum += $1
    sumsq += $1 * $1
    count++
}
END {
    mean = sum / count
    variance = (sumsq / count) - (mean * mean)
    stddev = sqrt(variance)
    printf "平均: %.2f, 標準偏差: %.2f\n", mean, stddev
}' data.txt
```

### 4. テキスト置換と変換

#### 基本的な置換

```awk
# httpをhttpsに置換
awk '{gsub(/http/, "https"); print}' urls.txt

# 最初のマッチのみ置換
awk '{sub(/http/, "https"); print}' urls.txt

# 特定のフィールドのみ置換
awk '{gsub(/old/, "new", $2); print}' file.txt
```

#### 大文字/小文字変換

```awk
# 大文字に変換
awk '{print toupper($0)}' file.txt

# 小文字に変換
awk '{print tolower($0)}' file.txt

# 特定のフィールドのみ変換
awk '{$1 = toupper($1); print}' file.txt
```

#### フォーマット変換

```awk
# CSV を TSV に変換
awk -F, '{print $1 "\t" $2 "\t" $3}' input.csv

# 空白を正規化（連続する空白を1つにまとめる）
awk '{$1=$1; print}' file.txt

# 行末の空白を削除
awk '{sub(/[ \t]+$/, ""); print}' file.txt
```

### 5. レポート生成

複雑な集計レポートを生成できます。

#### グループ別集計

```awk
# ユーザーIDのレンジ別統計
awk -F: '
BEGIN { 
    print "UID範囲別ユーザー統計"
    print "===================="
}
$3 < 1000 { system_users++ }
$3 >= 1000 && $3 < 2000 { regular_users++ }
$3 >= 2000 { special_users++ }
END {
    printf "システムユーザー (0-999):     %d\n", system_users
    printf "通常ユーザー (1000-1999):     %d\n", regular_users
    printf "特別ユーザー (2000+):         %d\n", special_users
    printf "-----------------------------------\n"
    printf "合計:                         %d\n", system_users + regular_users + special_users
}' /etc/passwd
```

#### 売上レポート

```awk
# 商品別売上集計
awk -F, '
NR > 1 {  # ヘッダー行をスキップ
    product = $1
    sales = $2
    total[product] += sales
    count[product]++
}
END {
    print "商品別売上レポート"
    print "=================="
    for (product in total) {
        printf "%-20s: 売上 %10.2f 円 (取引数: %d)\n", 
               product, total[product], count[product]
    }
}' sales.csv
```

#### アクセスログ解析

```awk
# アクセスログからステータスコード別集計
awk '{
    status = $9
    count[status]++
    total++
}
END {
    print "ステータスコード別統計"
    print "====================="
    for (code in count) {
        percentage = (count[code] / total) * 100
        printf "%-3s: %6d回 (%.2f%%)\n", code, count[code], percentage
    }
    print "---------------------"
    printf "合計: %d\n", total
}' access.log
```

### 6. 条件分岐と制御構造

#### if-else文

```awk
awk '{
    if ($3 >= 90) 
        grade = "A"
    else if ($3 >= 80) 
        grade = "B"
    else if ($3 >= 70) 
        grade = "C"
    else 
        grade = "D"
    print $1, $2, grade
}' scores.txt
```

#### ループ処理

```awk
# for ループ
awk 'BEGIN {
    for (i = 1; i <= 10; i++) {
        print i * i
    }
}'

# while ループ
awk 'BEGIN {
    i = 1
    while (i <= 10) {
        print i
        i++
    }
}'

# 配列のループ
awk '{
    for (i = 1; i <= NF; i++) {
        print "フィールド" i ":", $i
    }
}' file.txt
```

#### 行範囲の指定

```awk
# 10行目から20行目までを処理
awk 'NR >= 10 && NR <= 20 {print}' file.txt

# パターンで範囲を指定
awk '/START/,/END/ {print}' file.txt

# 最初の5行をスキップ
awk 'NR > 5 {print}' file.txt
```

### 7. 配列操作

#### 連想配列

```awk
# 単語の出現回数をカウント
awk '{
    for (i = 1; i <= NF; i++) {
        word[$i]++
    }
}
END {
    for (w in word) {
        print w, word[w]
    }
}' text.txt
```

#### 多次元配列

```awk
# 2次元配列（疑似）
awk '{
    key = $1 SUBSEP $2
    data[key] = $3
}
END {
    for (k in data) {
        print k, data[k]
    }
}' file.txt
```

#### 配列のソート

```awk
# 配列を値でソート
awk '{
    count[$1]++
}
END {
    # 配列をソートして出力（asort使用）
    n = asort(count, sorted)
    for (i = 1; i <= n; i++) {
        print sorted[i]
    }
}' file.txt
```

### 8. 関数の使用

#### ユーザー定義関数

```awk
# 階乗計算
awk '
function factorial(n) {
    if (n <= 1) return 1
    return n * factorial(n - 1)
}
BEGIN {
    for (i = 1; i <= 10; i++) {
        print i "! =", factorial(i)
    }
}'
```

#### 文字列操作関数

```awk
# 文字列関数の使用例
awk '{
    # 長さを取得
    len = length($1)
    
    # 部分文字列を抽出
    sub_str = substr($1, 1, 3)
    
    # 文字列の位置を検索
    pos = index($1, "test")
    
    # 分割
    n = split($1, arr, ",")
    
    print len, sub_str, pos, n
}' file.txt
```

## 実践的な使用例

### CSVファイルの処理

```awk
# CSVから特定の列を抽出してフォーマット
awk -F, 'NR > 1 {printf "%-20s %10.2f\n", $1, $2}' data.csv

# CSVの列を入れ替え
awk -F, '{print $3 "," $1 "," $2}' input.csv > output.csv

# CSV の重複行を削除
awk -F, '!seen[$1]++' data.csv
```

### ログファイル解析

```awk
# エラー行のみを抽出
awk '/ERROR/ {print $1, $2, $0}' app.log

# 特定の時間帯のログを抽出
awk '$2 >= "09:00:00" && $2 <= "17:00:00"' access.log

# IPアドレス別アクセス数
awk '{ip[$1]++} END {for (i in ip) print i, ip[i]}' access.log | sort -k2 -nr
```

### システム管理

```awk
# プロセスのメモリ使用量を集計
ps aux | awk 'NR > 1 {sum += $6} END {printf "合計メモリ使用量: %.2f MB\n", sum/1024}'

# ディスク使用量のトップ10
df -h | awk 'NR > 1 {print $5, $6}' | sort -nr | head -10

# 大きなファイルを検索
find . -type f -exec ls -l {} \; | awk '$5 > 10485760 {print $9, $5/1048576 "MB"}'
```

### データ変換

```awk
# JSON風の出力を生成
awk -F, 'NR > 1 {
    printf "{\n"
    printf "  \"name\": \"%s\",\n", $1
    printf "  \"age\": %d,\n", $2
    printf "  \"city\": \"%s\"\n", $3
    printf "},\n"
}' data.csv

# Markdownテーブルを生成
awk -F, 'BEGIN {print "| 名前 | 年齢 | 都市 |"; print "|------|------|------|"}
         NR > 1 {printf "| %s | %s | %s |\n", $1, $2, $3}' data.csv
```

## 組み込み変数

| 変数 | 説明 | 例 |
|------|------|-----|
| `$0` | 現在の行全体 | `awk '{print $0}' file` |
| `$1, $2, ...` | 各フィールド | `awk '{print $1, $3}' file` |
| `NF` | 現在の行のフィールド数 | `awk '{print NF}' file` |
| `NR` | 現在の行番号（全ファイル通算） | `awk '{print NR, $0}' file` |
| `FNR` | 現在のファイル内での行番号 | `awk '{print FNR}' file` |
| `FS` | 入力フィールド区切り文字 | `awk 'BEGIN {FS=":"} {print $1}' file` |
| `OFS` | 出力フィールド区切り文字 | `awk 'BEGIN {OFS="\t"} {print $1, $2}' file` |
| `RS` | 入力レコード区切り文字 | `awk 'BEGIN {RS=";"} {print}' file` |
| `ORS` | 出力レコード区切り文字 | `awk 'BEGIN {ORS="\n\n"} {print}' file` |
| `FILENAME` | 現在処理中のファイル名 | `awk '{print FILENAME, $0}' file` |

## 組み込み関数

### 数値関数

```awk
int(x)       # 整数部を返す
sqrt(x)      # 平方根
sin(x)       # サイン
cos(x)       # コサイン
atan2(y,x)   # アークタンジェント
exp(x)       # e^x
log(x)       # 自然対数
rand()       # 0-1の乱数
srand(x)     # 乱数シードを設定
```

### 文字列関数

```awk
length(s)           # 文字列の長さ
substr(s, i, n)     # 部分文字列を抽出
index(s, t)         # 文字列tの位置
split(s, a, fs)     # 文字列を分割して配列に格納
sub(r, s, t)        # 最初のマッチを置換
gsub(r, s, t)       # すべてのマッチを置換
match(s, r)         # 正規表現マッチの位置
toupper(s)          # 大文字に変換
tolower(s)          # 小文字に変換
sprintf(fmt, ...)   # フォーマット済み文字列を返す
```

## ベストプラクティス

### 1. 可読性を重視する

```awk
# 悪い例
awk -F: '$3>=1000&&$7~/bash/{print$1,$3}' /etc/passwd

# 良い例
awk -F: '
    $3 >= 1000 && $7 ~ /bash/ {
        print $1, $3
    }
' /etc/passwd
```

### 2. スクリプトファイルを使用する

複雑な処理は外部ファイルに保存:

```awk
# script.awk
BEGIN {
    FS = ":"
    OFS = "\t"
    print "ユーザー名\tUID"
}

$3 >= 1000 {
    print $1, $3
}

END {
    print "処理完了"
}
```

実行:
```bash
awk -f script.awk /etc/passwd
```

### 3. エラーハンドリング

```awk
awk '{
    if (NF < 3) {
        print "警告: 行", NR, "のフィールド数が不足" > "/dev/stderr"
        next
    }
    print $1, $2, $3
}' file.txt
```

### 4. デバッグ

```awk
# デバッグ出力を追加
awk '{
    print "DEBUG: NR=" NR ", NF=" NF > "/dev/stderr"
    print $0
}' file.txt
```

### 5. パフォーマンス最適化

```awk
# 不要な処理を避ける
awk 'NR > 1000 {exit}  # 1000行で処理を終了
     {print $1}' large_file.txt

# 正規表現を事前にコンパイル（変数に格納）
awk 'BEGIN {pattern = "^[0-9]+$"}
     $1 ~ pattern {print}' file.txt
```

## 参考資料

### 公式ドキュメント

- [GNU AWK User's Guide](https://www.gnu.org/software/gawk/manual/)
- [POSIX AWK仕様](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html)

### 書籍

- "The AWK Programming Language" - Aho, Weinberger, Kernighan
- "sed & awk (第2版)" - Dale Dougherty, Arnold Robbins

### オンラインリソース

- [AWK チュートリアル](https://www.grymoire.com/Unix/Awk.html)
- [AWK one-liners](http://www.pement.org/awk/awk1line.txt)

### コミュニティ

- Stack Overflow - [awk タグ](https://stackoverflow.com/questions/tagged/awk)
- Unix & Linux Stack Exchange

---

**作成日**: 2025-11-18  
**バージョン**: 1.0  
**ライセンス**: MIT
