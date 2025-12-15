# セキュリティテスト - Security Testing

**作成日**: 2025-12-02
**バージョン**: 1.0
**担当**: Infrastructure Security Team

---

## 📋 目次

1. [概要](#概要)
2. [発見されたセキュリティ脆弱性](#発見されたセキュリティ脆弱性)
3. [テストの実行方法](#テストの実行方法)
4. [テストファイルの説明](#テストファイルの説明)
5. [セキュリティ修正ガイド](#セキュリティ修正ガイド)
6. [CI/CD統合](#cicd統合)
7. [セキュリティチェックリスト](#セキュリティチェックリスト)

---

## 概要

このディレクトリには、My-infraリポジトリのセキュリティテストが含まれています。以下の脆弱性を検出・防止することを目的としています:

### 検出対象の脆弱性

| 脆弱性タイプ | リスクレベル | テストファイル |
|------------|------------|--------------|
| 認証情報の漏洩 | 🔴 CRITICAL | `test_credential_exposure.bats` |
| コマンドインジェクション | 🔴 CRITICAL | `test_command_injection.bats` |
| SQLインジェクション | 🔴 CRITICAL | `test_input_validation.py` |
| XSSインジェクション | 🟡 HIGH | `test_input_validation.py` |
| パストラバーサル | 🟡 HIGH | `test_command_injection.bats` |
| 弱いパスワードハッシュ | 🟡 HIGH | `test_input_validation.py` |
| 入力検証不足 | 🟡 HIGH | `test_input_validation.py` |

---

## 発見されたセキュリティ脆弱性

### 🔴 CRITICAL: ハードコードされた認証情報

**場所**: `DB/SQL.crash.sh`

```bash
# 危険なコード
DB_USER="your_username"
DB_PASS="your_password"
DB_NAME="your_database"
```

**リスク**:
- 認証情報がGitリポジトリに保存される
- 誰でもアクセス可能
- パスワード変更時の追跡困難

**修正方法**:
```bash
# 環境変数から読み込む
DB_USER="${DB_USER:-}"
DB_PASS="${DB_PASS:-}"
DB_NAME="${DB_NAME:-}"

# または設定ファイルから読み込む
if [ -f /etc/myapp/db.conf ]; then
    source /etc/myapp/db.conf
fi

# 必須項目のチェック
[ -z "$DB_USER" ] && error_exit "DB_USER環境変数が設定されていません"
[ -z "$DB_PASS" ] && error_exit "DB_PASS環境変数が設定されていません"
```

---

### 🔴 CRITICAL: コマンドラインでのパスワード露出

**場所**: `DB/db.check-everyday.sh:40`, `DB/SQL.crash.sh:28`

```bash
# 危険なコード
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1"
```

**リスク**:
- パスワードが `ps aux` で見える
- プロセスリストから第三者が取得可能
- ログファイルに記録される可能性

**修正方法**:

```bash
# 方法1: MYSQL_PWD環境変数を使用
export MYSQL_PWD="$DB_PASS"
mysql -h "$DB_HOST" -u "$DB_USER" -e "SELECT 1"
unset MYSQL_PWD

# 方法2: 設定ファイルを使用
cat > /tmp/.my.cnf << EOF
[client]
user=$DB_USER
password=$DB_PASS
host=$DB_HOST
EOF

chmod 600 /tmp/.my.cnf
mysql --defaults-file=/tmp/.my.cnf -e "SELECT 1"
rm -f /tmp/.my.cnf

# 方法3: パスワードプロンプト（インタラクティブな場合）
mysql -h "$DB_HOST" -u "$DB_USER" -p
```

---

### 🔴 CRITICAL: 弱いパスワードハッシュ

**場所**: `security/automatic.py:18-20`

```python
# 危険なコード
def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()
```

**リスク**:
- SHA256は高速すぎる（総当たり攻撃に弱い）
- Salt がない（レインボーテーブル攻撃に脆弱）
- 同じパスワードで常に同じハッシュ

**修正方法**:

```python
import bcrypt

def hash_password(password):
    """パスワードを安全にハッシュ化する"""
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def verify_password(password, hashed):
    """パスワードを検証する"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))
```

または Argon2 を使用:

```python
from argon2 import PasswordHasher

ph = PasswordHasher()

def hash_password(password):
    return ph.hash(password)

def verify_password(password, hashed):
    try:
        ph.verify(hashed, password)
        return True
    except:
        return False
```

---

### 🟡 HIGH: SQLインジェクション脆弱性

**場所**: 複数のスクリプトで変数が直接SQL文に埋め込まれている

```bash
# 危険なコード
user_input="$1"
mysql -e "SELECT * FROM users WHERE name='$user_input'"
# user_input="admin'; DROP TABLE users;--" の場合に危険
```

**修正方法**:

```bash
# 方法1: 入力を検証する
validate_input() {
    local input="$1"
    # 英数字とアンダースコアのみ許可
    if [[ ! "$input" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo "エラー: 無効な入力" >&2
        return 1
    fi
    echo "$input"
}

safe_input=$(validate_input "$user_input") || exit 1
mysql -e "SELECT * FROM users WHERE name='$safe_input'"

# 方法2: シングルクォートをエスケープ
escape_sql() {
    echo "${1//\'/\'\'}"
}

safe_input=$(escape_sql "$user_input")
mysql -e "SELECT * FROM users WHERE name='$safe_input'"

# 方法3: プリペアドステートメント（推奨）
mysql <<EOF
SET @user_name = '$user_input';
PREPARE stmt FROM 'SELECT * FROM users WHERE name = ?';
EXECUTE stmt USING @user_name;
DEALLOCATE PREPARE stmt;
EOF
```

---

### 🟡 HIGH: クォートされていない変数展開

**場所**: 複数のスクリプト

```bash
# 危険なコード
file_name="$1"
rm -f $file_name  # スペースで分割される
```

**リスク**:
- `file_name="file1.txt file2.txt"` の場合、2つのファイルが削除される
- ワイルドカードが展開される
- 意図しない動作

**修正方法**:

```bash
# 安全なコード
file_name="$1"
rm -f "$file_name"  # ダブルクォートで囲む

# 配列の場合
files=("file1.txt" "file2.txt")
rm -f "${files[@]}"  # 配列を正しく展開
```

---

## テストの実行方法

### 前提条件

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y bats shellcheck python3-pip

# macOS
brew install bats-core shellcheck python3

# Python依存関係
pip install pytest bcrypt argon2-cffi
```

### すべてのセキュリティテストを実行

```bash
# BATSテスト
bats tests/security/test_credential_exposure.bats
bats tests/security/test_command_injection.bats

# Pythonテスト
python3 -m pytest tests/security/test_input_validation.py -v
```

### 個別テストの実行

```bash
# 認証情報スキャンのみ
bats tests/security/test_credential_exposure.bats

# 特定のテストケースのみ
bats tests/security/test_credential_exposure.bats --filter "ハードコード"

# Pythonの特定のクラスのみ
python3 -m pytest tests/security/test_input_validation.py::TestEmailValidationSecurity -v
```

### Verbose モード

```bash
# 詳細な出力
bats tests/security/test_credential_exposure.bats --verbose

# Pythonで詳細出力
python3 -m pytest tests/security/test_input_validation.py -vv -s
```

---

## テストファイルの説明

### `test_credential_exposure.bats`

認証情報の漏洩を検出します。

**テスト項目**:
- ✅ ハードコードされたパスワード
- ✅ AWSキーの漏洩
- ✅ プライベートキーの存在
- ✅ コマンドライン引数でのパスワード露出
- ✅ .envファイルの.gitignore設定
- ✅ ファイルパーミッション
- ✅ JWTトークンの漏洩
- ✅ Git履歴の確認

**実行例**:
```bash
$ bats tests/security/test_credential_exposure.bats

 ✓ スクリプトにパスワードがハードコードされていない
 ✗ MySQLコマンドでパスワードがコマンドライン引数に含まれていない
   DB/SQL.crash.sh:28: mysql -p"$DB_PASS"
 ✓ プライベートキーがリポジトリに含まれていない
 ✓ .envファイルが.gitignoreに含まれている

4 tests, 1 failure
```

---

### `test_command_injection.bats`

コマンドインジェクションの脆弱性を検出します。

**テスト項目**:
- ✅ `eval` の危険な使用
- ✅ クォートされていない変数
- ✅ コマンド置換でのユーザー入力
- ✅ SQLインジェクション
- ✅ パストラバーサル
- ✅ システムコマンド実行
- ✅ 入力検証

**実行例**:
```bash
$ bats tests/security/test_command_injection.bats

 ✓ evalコマンドが使用されていない
 ✓ シェル変数が適切にクォートされている
 ✗ SQL文に変数が直接埋め込まれていない
   DB/db.check-everyday.sh:65: mysql -e "SELECT ... WHERE id=$user_id"
 ✓ 入力検証のテスト

4 tests, 1 failure
```

---

### `test_input_validation.py`

Python入力検証のセキュリティテストです。

**テスト項目**:
- ✅ メールインジェクション（CRLF）
- ✅ SQLインジェクション試行
- ✅ XSS攻撃
- ✅ パスワード強度
- ✅ クレジットカード検証
- ✅ JSONインジェクション
- ✅ 日付検証

**実行例**:
```bash
$ python3 -m pytest tests/security/test_input_validation.py -v

test_email_injection_crlf PASSED                     [ 10%]
test_email_sql_injection PASSED                      [ 20%]
test_password_hashing_strength FAILED                [ 30%]
  AssertionError: SHA256はパスワードハッシュに不適切

30 passed, 1 failed
```

---

## セキュリティ修正ガイド

### 優先度付け

1. **🔴 CRITICAL** - 即座に修正が必要
   - ハードコードされた認証情報
   - コマンドライン露出パスワード
   - SQLインジェクション

2. **🟡 HIGH** - 1週間以内に修正
   - 弱いパスワードハッシュ
   - 入力検証不足
   - パストラバーサル

3. **🟢 MEDIUM** - 次回スプリントで修正
   - ログの機密情報
   - エラーメッセージの詳細すぎる情報

### 修正手順

#### ステップ1: 影響範囲の特定

```bash
# 影響を受けるスクリプトをリストアップ
grep -r "mysql.*-p\$" DB/
grep -r "PASSWORD=" .
```

#### ステップ2: テスト環境で修正

```bash
# ブランチを作成
git checkout -b security/fix-password-exposure

# 修正を実施
vim DB/SQL.crash.sh

# テストを実行
bats tests/security/test_credential_exposure.bats
```

#### ステップ3: 本番環境への適用

```bash
# Pull Requestを作成
gh pr create --title "Security: パスワード露出の修正" \
             --body "DB/SQL.crash.shのパスワード露出を修正"

# レビュー後にマージ
```

---

## CI/CD統合

### GitHub Actions

`.github/workflows/security-tests.yml` が自動的に以下を実行します:

1. **認証情報スキャン** (gitleaks)
2. **シェルスクリプト静的解析** (shellcheck)
3. **コマンドインジェクション検査** (BATS)
4. **Python入力検証** (pytest)
5. **依存関係スキャン** (Trivy, Bandit)

### 手動実行

```bash
# GitHub Actionsで手動実行
gh workflow run security-tests.yml

# ローカルで実行
act -j security-summary
```

### Pre-commit フック

```bash
# .git/hooks/pre-commit に追加
#!/bin/bash

echo "🔒 セキュリティチェック実行中..."

# 認証情報スキャン
if grep -r "PASSWORD=[\"\'][^$]" .; then
    echo "❌ ハードコードされたパスワードが検出されました"
    exit 1
fi

# shellcheck
find . -name "*.sh" -type f -exec shellcheck {} \; || exit 1

echo "✅ セキュリティチェック完了"
```

---

## セキュリティチェックリスト

### コード作成時

- [ ] 認証情報を環境変数から読み込む
- [ ] パスワードをコマンドライン引数に含めない
- [ ] ユーザー入力を検証する
- [ ] 変数をダブルクォートで囲む
- [ ] SQLはプリペアドステートメントを使用
- [ ] パスワードは bcrypt/argon2 でハッシュ化
- [ ] ファイルパスは basename で正規化
- [ ] `eval` の使用を避ける
- [ ] エラーメッセージに機密情報を含めない

### コードレビュー時

- [ ] セキュリティテストが通過している
- [ ] shellcheck の警告がない
- [ ] 認証情報が含まれていない
- [ ] 入力検証が適切
- [ ] エラーハンドリングが実装されている

### デプロイ前

- [ ] すべてのセキュリティテストが成功
- [ ] 依存関係に既知の脆弱性がない
- [ ] 本番環境の認証情報が設定されている
- [ ] ログに機密情報が出力されない

---

## 参考資料

### セキュリティガイドライン

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

### ツールドキュメント

- [shellcheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [gitleaks](https://github.com/gitleaks/gitleaks)
- [Bandit](https://bandit.readthedocs.io/)
- [BATS](https://bats-core.readthedocs.io/)

### ベストプラクティス

- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide/Practices)
- [Python Security Best Practices](https://python.readthedocs.io/en/stable/library/security_warnings.html)

---

## サポート

質問や問題がある場合:

1. GitHub Issueを作成
2. セキュリティチームに連絡
3. このREADMEを更新（改善提案）

---

**最終更新**: 2025-12-02
**次回レビュー**: 2025-03-02
