#!/bin/bash
set -euo pipefail

# 日本語クイズシステムのセットアップスクリプト
# ディレクトリ構造とクイズアプリケーションの初期設定を作成

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly QUIZ_ROOT="japanese_quiz"
readonly CATEGORIES=("grammar" "vocabulary" "reading" "logic" "math" "culture")

# エラーハンドリング
trap 'echo "エラーが発生しました (行: $LINENO)" >&2; exit 1' ERR

# ディレクトリ構造を作成
create_directory_structure() {
    local base_dir="$1"
    
    echo "ディレクトリ構造を作成中..."
    mkdir -p "${base_dir}"/{questions,answers,data}
    
    for category in "${CATEGORIES[@]}"; do
        mkdir -p "${base_dir}/questions/${category}"
        mkdir -p "${base_dir}/answers/${category}"
        echo "  ✓ カテゴリを作成: ${category}"
    done
}

# 設定ファイルを作成
create_config_file() {
    local config_path="$1/config.sh"
    
    echo "設定ファイルを作成中..."
    cat > "${config_path}" << 'EOL'
#!/bin/bash
# Configuration for Japanese Quiz Application

readonly QUIZ_NAME="Japanese Proficiency Test Practice"
readonly QUIZ_VERSION="1.0"
readonly LANGUAGE="ja_JP"
readonly MAX_QUESTIONS_PER_SESSION=10
readonly RANDOMIZE_QUESTIONS=true
readonly SHOW_CORRECT_ANSWERS=true
EOL
    
    chmod +x "${config_path}"
    echo "  ✓ 設定ファイルを作成: ${config_path}"
}

# メイン処理
main() {
    echo "=== 日本語クイズシステムのセットアップ ==="
    echo
    
    create_directory_structure "${QUIZ_ROOT}"
    create_config_file "${QUIZ_ROOT}"
    
    echo
    echo "✅ セットアップが完了しました!"
    echo "   場所: ${QUIZ_ROOT}/"
}

main "$@"
