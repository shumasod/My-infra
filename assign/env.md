環境変数に関する重要なベストプラクティスを説明させていただきます：

1. 環境変数名は大文字で統一する - 環境変数は一目で識別できるように慣習的に大文字を使用します：
```bash
export DATABASE_URL="postgresql://localhost:5432/mydb"
export API_KEY="secret123"
```

2. 機密情報は環境変数で管理する - パスワードやAPIキーなどの機密情報はハードコードせず、環境変数として管理します：
```bash
# 良い例
database_connect "${DB_PASSWORD}"
# 悪い例
database_connect "password123"  # ハードコードは避ける
```

3. デフォルト値を設定する - 環境変数が未設定の場合のフォールバック値を指定します：
```bash
: "${PORT:=3000}"
: "${LOG_LEVEL:=info}"
```

4. 必須の環境変数をチェックする - アプリケーション起動時に必須の環境変数が設定されているか確認します：
```bash
if [ -z "${DATABASE_URL}" ]; then
    echo "ERROR: DATABASE_URL must be set"
    exit 1
fi
```

5. 名前空間を使用する - アプリケーション固有の環境変数にはプレフィックスをつけます：
```bash
export MYAPP_DATABASE_HOST="localhost"
export MYAPP_DATABASE_PORT="5432"
```

6. パスの結合は慎重に行う - PATHなどの環境変数を更新する際は既存の値を保持します：
```bash
export PATH="${NEW_PATH}:${PATH}"
```

7. 一時的な環境変数はスコープを限定する - サブシェルでのみ必要な環境変数は限定的に設定します：
```bash
(
    export TEMPORARY_VAR="value"
    ./script.sh
)
```

8. 環境変数のエクスポートを明示的に行う - 子プロセスに引き継ぐ必要がある変数は明示的にexportします：
```bash
# 良い例
export API_ENDPOINT="https://api.example.com"
# 悪い例（exportしていない）
API_ENDPOINT="https://api.example.com"
```

9. 設定ファイルと環境変数を併用する - 開発環境と本番環境で異なる設定を管理します：
```bash
# config.sh
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT="${DB_PORT:-5432}"
```

10. 環境変数の検証を実装する - 設定された値が有効かチェックします：
```bash
if [[ ! "${LOG_LEVEL}" =~ ^(debug|info|warn|error)$ ]]; then
    echo "Invalid LOG_LEVEL. Must be one of: debug, info, warn, error"
    exit 1
fi
```

11. ドキュメント化する - 必要な環境変数とその形式を明確に文書化します：
```bash
# Required Environment Variables:
# - DATABASE_URL: PostgreSQL connection string (postgresql://user:pass@host:port/db)
# - API_KEY: Valid API key for external service
# - LOG_LEVEL: Logging level (debug|info|warn|error)
```

12. 環境変数の値をログに出力しない - セキュリティ上の理由から、機密性の高い環境変数の値はログに出力しません：
```bash
# 良い例
logger "Database connection established"
# 悪い例
logger "Connected to database with password: ${DB_PASSWORD}"
```

13. 環境変数ファイルの管理 - .envファイルはバージョン管理から除外し、テンプレートを提供します：
```bash
# .env.template
DATABASE_URL=
API_KEY=
LOG_LEVEL=info
```

14. 複数の環境に対応する - 環境ごとに異なる設定を管理します：
```bash
# development.env
export API_URL="http://localhost:3000"

# production.env
export API_URL="https://api.production.com"
```

15. 型のバリデーションを実装する - 数値や真偽値の環境変数は適切な型チェックを行います：
```bash
if ! [[ "${PORT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: PORT must be a number"
    exit 1
fi

if ! [[ "${DEBUG}" =~ ^(true|false)$ ]]; then
    echo "ERROR: DEBUG must be true or false"
    exit 1
fi
```

これらのベストプラクティスを適用することで、より安全で管理しやすい環境変数の運用が可能になります。特に重要なのは、セキュリティと可用性のバランスを取ることです。環境変数は設定管理の重要な要素であり、適切な取り扱いが必要です。
