```markdown
# AWK

AWKは、テキスト処理のためのプログラミング言語およびユーティリティです。AWKスクリプトは主に行ベースのテキスト処理に使用され、パターンマッチングと関連するアクションの実行を行います。

## AWKでできること

AWKは、以下のようなタスクを実行できます。

### 1. フィールド抽出

テキストファイルからフィールド(区切り文字で区切られた値)を抽出できます。

```awk
# /etc/passwdファイルから第1フィールド(ユーザー名)を抽出
awk -F: '{print $1}' /etc/passwd
```

### 2. パターンマッチング

特定のパターンにマッチする行を抽出できます。

```awk
# /etc/passwdからrootユーザーの行を抽出
awk -F: '$1 == "root" {print $0}' /etc/passwd
```

### 3. 計算

awkは計算も可能です。

```awk
# 1から10までの合計を計算
awk 'BEGIN {sum=0; for(i=1; i<=10; i++) sum+=i; print sum}'
```

### 4. テキスト置換

特定のパターンにマッチするテキストを置換できます。

```awk
# httpをhttpsに置換
awk '{gsub(/http/, "https"); print}' file.txt
```

### 5. レポート生成

awkを使ってレポートを生成することができます。

```awk
# /etc/passwdからユーザーIDの統計を出力
awk -F: 'BEGIN { count[0]=count[1]=count[2]=count[3]=0 }
          $3 >= 1000 { count[$3-($3%1000)/1000]++ }
          END {
              printf "0-999:   %d users\n", count[0]
              printf "1000-1999: %d users\n", count[1]
              printf "2000-2999: %d users\n", count[2]
              printf "3000-3999: %d users\n", count[3]
          }' /etc/passwd
```

AWKは、シェルスクリプトやその他のスクリプト言語と組み合わせて使用することで、より高度なテキスト処理タスクを実行できます。

```

このREADME.mdには、awkの簡単な説明と、awkで実行できるタスクの具体例が含まれています。フィールド抽出、パターンマッチング、計算、テキスト置換、レポート生成などの機能が紹介されています。
