# CLAUDE.md - AI Assistant Guide for My-infra Repository

**Last Updated:** 2025-12-02
**Version:** 1.0.0
**Repository:** My-infra - Infrastructure Automation & System Administration Toolkit

---

## Table of Contents

1. [Repository Overview](#repository-overview)
2. [Project Structure](#project-structure)
3. [Technology Stack](#technology-stack)
4. [Coding Conventions](#coding-conventions)
5. [Development Workflows](#development-workflows)
6. [Git Practices](#git-practices)
7. [File Organization](#file-organization)
8. [Common Patterns](#common-patterns)
9. [Testing Guidelines](#testing-guidelines)
10. [Documentation Standards](#documentation-standards)
11. [AI Assistant Guidelines](#ai-assistant-guidelines)

---

## Repository Overview

### Purpose
My-infra is a comprehensive **Shell Script Collection for Infrastructure & Business Automation** designed to reduce operational workload and improve IT efficiency. The repository contains utilities for:

- Data processing and validation
- Database management and backup automation
- Cloud infrastructure (AWS, Google Cloud)
- System administration tasks
- Windows PC provisioning (kitting)
- Network management and monitoring

### Key Characteristics
- **Primary Language:** Bash/Shell scripts (172 files, 54% of codebase)
- **Version:** 1.2.0
- **License:** MIT
- **Documentation Language:** Primarily Japanese
- **Maturity:** Active development with frequent commits
- **Target Users:** IT professionals, system administrators, DevOps engineers

### Repository Statistics
- **Total Files:** 315+
- **Total Directories:** 61
- **Languages:** 12+ (Bash, SQL, Python, PowerShell, Go, JavaScript, YAML, etc.)
- **Database Systems:** 6 (MySQL, PostgreSQL, MongoDB, Redis/Valkey, DynamoDB, Oracle)
- **Cloud Providers:** AWS, Google Cloud Platform

---

## Project Structure

### Root Level Organization

```
/home/user/My-infra/
├── AWS/                    # Amazon Web Services automation
├── Google/                 # Google Cloud services
├── Bigquery/              # BigQuery data warehouse management
├── DB/                    # General database management
├── DynamoDB/              # AWS DynamoDB specific
├── MongoDB/               # MongoDB documentation & tools
├── mysql/                 # MySQL utilities
├── redis/                 # Redis configuration
├── Valkey/                # Valkey cluster management
├── deploy/                # Deployment automation
├── server/                # Server management scripts
├── network/               # Network infrastructure
├── security/              # Security validation
├── pc/                    # Windows PC management
├── assign/                # Environment configuration
├── Validation/            # Input validation utilities
├── game/                  # Entertainment utilities
├── awk/                   # AWK programming examples
├── query/                 # SQL query examples
├── http/                  # HTTP monitoring
├── work/                  # Workflow automation
├── 2025/                  # Calendar/scheduling
├── Timer.sh               # Countdown timer utility (v2.0)
├── MCP.sh                 # ASCII art animation
├── Quiz.sh                # Japanese quiz system
├── site.yml               # Ansible playbook (Valkey cluster)
├── inventory.ini          # Ansible inventory
├── README.md              # Main documentation (Japanese)
└── CLAUDE.md              # This file
```

### Domain-Specific Directories

#### Infrastructure & Cloud
- **AWS/**: ALB configs, auto-scaling, SSO, CLI scripts
- **Google/**: GAS (Google Apps Scripts), Cloud services
- **Bigquery/**: Dataset operations, query management
- **deploy/**: Deployment automation scripts

#### Databases
- **DB/**: Cross-database tools (MySQL, PostgreSQL, backup/restore)
- **mongodb/**: MongoDB utilities, SQL examples
- **mysql/**: MySQL backup, Docker configs, batch tools
- **redis/**, **Valkey/**: Redis/Valkey configurations and cluster setup
- **DynamoDB/**: AWS DynamoDB management

#### System Administration
- **server/**: SSH, monitoring, backups, disk management
- **network/**: Network testing, calculations
- **security/**: Validation, policy enforcement
- **pc/**: Windows management (PowerShell scripts)

#### Development & Utilities
- **Validation/**: Input validators (Luhn, email, phone, password)
- **query/**: SQL query examples (1.sql - 5.sql)
- **awk/**: AWK programming examples
- **game/**: Educational games and utilities

---

## Technology Stack

### Primary Technologies

| Technology | Usage | File Count |
|-----------|-------|------------|
| Bash/Shell | Infrastructure automation, system tasks | 172 |
| SQL | Database queries, schema management | 19 |
| Markdown | Documentation | 15 |
| PowerShell | Windows PC management | 12 |
| YAML | Infrastructure as Code | 7 |
| Python | Data processing, validation | 4 |
| JavaScript | GAS automation, crypto tools | 2 |
| Go | High-performance data processing | 1 |

### Infrastructure Tools
- **Container Orchestration:** Docker, Docker Compose
- **Configuration Management:** Ansible
- **Infrastructure as Code:** Terraform
- **Version Control:** Git

### Cloud Platforms
- **AWS:** EC2, ALB, DynamoDB, Elasticache, RDS, Auto-scaling, SSO
- **Google Cloud:** BigQuery, Sheets API, Google Apps Scripts

### Databases
- **Relational:** MySQL/MariaDB, PostgreSQL, Oracle DB
- **NoSQL:** MongoDB, DynamoDB
- **Cache/Key-Value:** Redis, Valkey

---

## Coding Conventions

### Shell Script Standards

#### Script Headers
All shell scripts should follow this header pattern:

```bash
#!/bin/bash
set -euo pipefail

#
# スクリプト名の説明
# 作成日: YYYY-MM-DD
# バージョン: X.Y
#
# 詳細説明をここに記述
#
```

**Flags Explained:**
- `set -e`: Exit immediately if a command exits with non-zero status
- `set -u`: Exit if an undefined variable is used
- `set -o pipefail`: Pipeline fails if any command fails (not just the last)

#### Constants and Variables
```bash
# 定数は readonly で定義
readonly PROG_NAME=$(basename "$0")
readonly VERSION="2.0"
readonly MAX_RETRIES=3

# グローバル変数は declare で型指定
declare -i counter=0
declare config_file=""
declare -i verbose_mode=false
```

#### Function Organization
Scripts should be organized into logical sections:

```bash
# ===== 設定（定数） =====
# Constants here

# ===== グローバル変数 =====
# Global variables here

# ===== ヘルパー関数 =====
# Helper functions here

# ===== メインロジック =====
# Main logic functions here

# ===== 引数解析 =====
# Argument parsing here

# ===== メイン処理 =====
main() {
    # Main entry point
}

# スクリプト実行
main "$@"
```

#### Error Handling
```bash
# エラーメッセージを表示して終了
error_exit() {
    echo -e "${COLOR_ERROR}エラー: $1${COLOR_RESET}" >&2
    echo "詳しい使用方法は「$PROG_NAME --help」を参照してください" >&2
    exit 1
}

# トラップを使用してクリーンアップ
cleanup() {
    # クリーンアップ処理
    rm -f "${temp_file}"
}

trap cleanup EXIT
trap 'error_exit "中断されました"' INT TERM
```

#### Input Validation
```bash
validate_number() {
    local value="$1"
    local min="$2"
    local max="$3"
    local name="$4"

    if ! [[ $value =~ ^[0-9]+$ ]]; then
        error_exit "${name}は数字である必要があります: $value"
    fi

    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        error_exit "${name}は${min}から${max}の範囲で指定してください: $value"
    fi
}
```

#### Command-Line Argument Parsing
```bash
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -t|--title)
                [ $# -lt 2 ] && error_exit "--title オプションには値が必要です"
                title="$2"
                shift 2
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                positional_arg="$1"
                shift
                ;;
        esac
    done
}
```

### Color Codes for Output
```bash
readonly COLOR_TITLE='\033[1;36m'    # シアン（太字）
readonly COLOR_TIME='\033[1;32m'     # 緑（太字）
readonly COLOR_PROGRESS='\033[1;33m' # 黄色（太字）
readonly COLOR_ERROR='\033[1;31m'    # 赤（太字）
readonly COLOR_SUCCESS='\033[1;32m'  # 緑（太字）
readonly COLOR_RESET='\033[0m'       # リセット
```

### Python Script Standards

```python
#!/usr/bin/env python3
"""
モジュールの説明

詳細な説明をここに記述
"""

import sys
import argparse
from typing import List, Dict, Optional

def main() -> int:
    """メイン関数"""
    parser = argparse.ArgumentParser(description='スクリプトの説明')
    # 引数定義
    args = parser.parse_args()

    try:
        # メイン処理
        return 0
    except Exception as e:
        print(f"エラー: {e}", file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
```

### PowerShell Script Standards

```powershell
#Requires -Version 5.1

<#
.SYNOPSIS
    スクリプトの概要

.DESCRIPTION
    詳細な説明

.PARAMETER ConfigFile
    設定ファイルのパス

.EXAMPLE
    .\script.ps1 -ConfigFile "config.json"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
```

### SQL Standards

```sql
-- ファイル名: query_description.sql
-- 作成日: YYYY-MM-DD
-- 説明: クエリの目的と詳細

-- テーブル構造の確認
SELECT
    column1,
    column2,
    COUNT(*) as record_count
FROM
    table_name
WHERE
    condition = 'value'
GROUP BY
    column1, column2
ORDER BY
    record_count DESC;
```

### YAML/Ansible Standards

```yaml
---
- name: Playbook Purpose - Phase Description
  hosts: target_hosts
  become: yes
  gather_facts: yes
  tags: [phase_tag, category_tag]

  vars:
    variable_name: value
    another_var: "string_value"

  tasks:
    - name: タスクの説明（日本語可）
      module_name:
        parameter: value
      register: result_variable

    - name: 結果の表示
      debug:
        var: result_variable
```

---

## Development Workflows

### Database Management Workflow

1. **Backup Creation**
   ```bash
   ./db_backup.sh -d <database_name> -t [full|diff]
   ```

2. **Integrity Check**
   ```bash
   ./integrity_check.sh -d <database_name>
   ```

3. **Restore Process**
   ```bash
   ./db_restore.sh -b <backup_file> -d <target_db>
   ```

4. **Performance Optimization**
   - Run query optimizers from `query/` directory
   - Review slow query logs
   - Apply index optimizations

### Cloud Deployment Pattern

1. **Infrastructure Setup**
   - Review Terraform configurations in `deploy/`
   - Apply infrastructure changes
   - Verify resource creation

2. **Auto-Scaling Configuration**
   - Configure DynamoDB auto-scaling
   - Set up Elasticache scaling policies
   - Configure ALB health checks

3. **Monitoring Setup**
   - Deploy monitoring scripts
   - Configure alerting thresholds
   - Set up log aggregation

### System Administration Workflow

1. **PC Provisioning (Windows)**
   ```powershell
   # 初期設定の適用
   .\initial_setup.ps1 -UserType [admin|standard|developer]

   # ソフトウェアのインストール
   .\install_software.ps1 -ConfigFile <config_file>

   # セキュリティポリシーの適用
   .\apply_policy.ps1 -PolicyTemplate <template>
   ```

2. **Server Management**
   - SSH key management
   - Backup automation
   - Disk space monitoring
   - Resource alerting

### Valkey/Redis Cluster Deployment

```bash
# Ansible playbook execution
ansible-playbook -i inventory.ini site.yml

# Phase-specific execution
ansible-playbook -i inventory.ini site.yml --tags phase1
ansible-playbook -i inventory.ini site.yml --tags phase2,phase3
```

### Data Processing Pipeline

1. **Data Extraction**
   - Use appropriate format exporter (CSV, JSON, SQL)
   - Validate data integrity

2. **Data Processing**
   - Apply transformations
   - Run validation scripts from `Validation/`
   - Generate reports

3. **Data Loading**
   - Import to target system
   - Verify record counts
   - Run post-import checks

---

## Git Practices

### Branch Strategy

Based on recent commits, the repository uses:
- **Main/Master branch**: Production-ready code
- **Feature branches**: Named with descriptive labels (e.g., `feature/35`)
- **Claude branches**: AI-generated work uses `claude/` prefix

### Commit Message Conventions

Recent commit patterns show:
```
<file_name> を更新          # Japanese update message
Update <file_name>           # English update message
Create <file_name>           # New file creation
Merge pull request #N        # PR merge
```

**Recommended Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント更新
- `style`: コードスタイル変更
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: その他の変更

### Pull Request Process

1. Create feature branch from main
2. Implement changes with appropriate tests
3. Update relevant documentation
4. Create PR with descriptive title and body
5. Address review feedback
6. Merge after approval

---

## File Organization

### Naming Conventions

#### Shell Scripts
- Use lowercase with underscores: `db_backup.sh`
- Descriptive names indicating purpose: `ec2_ssh_check1.sh`
- Version suffixes when applicable: `test1.sh`, `test2.sh`

#### Configuration Files
- Use descriptive names: `inventory.ini`, `site.yml`
- Include context: `docker-compose.yml`

#### Documentation
- Use README.md for directory documentation
- Specific docs use descriptive names: `AboutDomain.md`, `scal.md`

### Directory Structure Rules

1. **Functional Grouping**: Scripts are organized by technology/purpose
2. **Flat Structure**: Most directories are single-level
3. **Subdirectories**: Used for complex modules (e.g., `folder/Docker/`)

---

## Common Patterns

### Database Backup Script Pattern

```bash
#!/bin/bash
set -euo pipefail

# 設定
readonly BACKUP_DIR="/path/to/backups"
readonly DATE=$(date +%Y-%m-%d_%H%M%S)
readonly DB_NAME="$1"
readonly BACKUP_TYPE="${2:-full}"

# バックアップディレクトリ作成
mkdir -p "${BACKUP_DIR}"

# バックアップ実行
case "$BACKUP_TYPE" in
    full)
        mysqldump "${DB_NAME}" > "${BACKUP_DIR}/${DB_NAME}_${DATE}.sql"
        ;;
    diff)
        # 差分バックアップロジック
        ;;
esac

# 古いバックアップの削除（30日以上）
find "${BACKUP_DIR}" -name "*.sql" -mtime +30 -delete
```

### AWS Resource Management Pattern

```bash
#!/bin/bash
set -euo pipefail

# AWS CLIの確認
if ! command -v aws &> /dev/null; then
    echo "AWS CLI がインストールされていません" >&2
    exit 1
fi

# リージョン設定
readonly REGION="${AWS_REGION:-ap-northeast-1}"

# リソース操作
aws ec2 describe-instances \
    --region "${REGION}" \
    --filters "Name=tag:Environment,Values=production" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
    --output table
```

### Ansible Playbook Pattern

```yaml
---
- name: Infrastructure Setup - Phase 1
  hosts: target_group
  become: yes
  gather_facts: yes
  tags: [phase1, setup]

  vars:
    service_port: 6379
    config_dir: /etc/service
    data_dir: /var/lib/service

  tasks:
    - name: パッケージのインストール
      apt:
        name: "{{ item }}"
        state: present
        update_cache: yes
      loop:
        - package1
        - package2
      retries: 3
      delay: 5

    - name: 設定ファイルの作成
      template:
        src: config.j2
        dest: "{{ config_dir }}/config.conf"
        owner: service
        group: service
        mode: '0640'
      notify: restart service

  handlers:
    - name: restart service
      systemd:
        name: service
        state: restarted
```

### Validation Script Pattern

```bash
#!/bin/bash

validate_email() {
    local email="$1"
    local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    if [[ $email =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_phone() {
    local phone="$1"
    # 日本の電話番号形式
    local regex='^0[0-9]{9,10}$'

    if [[ $phone =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}
```

---

## Testing Guidelines

### Shell Script Testing

1. **Syntax Check**
   ```bash
   bash -n script.sh
   shellcheck script.sh
   ```

2. **Unit Testing**
   - Test individual functions with various inputs
   - Verify error handling
   - Check edge cases

3. **Integration Testing**
   - Test script with real resources (use test environment)
   - Verify backup/restore cycles
   - Test with different configurations

### Ansible Playbook Testing

```bash
# Syntax check
ansible-playbook site.yml --syntax-check

# Dry run (check mode)
ansible-playbook -i inventory.ini site.yml --check

# Test on single host
ansible-playbook -i inventory.ini site.yml --limit test-host
```

### Database Query Testing

1. **Explain Plans**
   ```sql
   EXPLAIN SELECT * FROM table WHERE condition;
   ```

2. **Performance Testing**
   - Test with production-like data volumes
   - Measure execution time
   - Check resource usage

---

## Documentation Standards

### README Structure

Each major directory should contain a README with:

```markdown
# ディレクトリ名

## 概要
このディレクトリの目的と内容

## ファイル一覧
- `file1.sh` - ファイルの説明
- `file2.sh` - ファイルの説明

## 使用方法
基本的な使用例

## 前提条件
必要な環境や依存関係

## 注意事項
重要な注意点
```

### Script Documentation

Every script should include:
1. **Header comments**: Purpose, author, version
2. **Usage function**: `--help` flag implementation
3. **Examples**: Common use cases
4. **Exit codes**: Documented return values

### Inline Comments

```bash
# 日本語でのコメントが推奨されます
# 複雑なロジックには詳細な説明を記述

# 英語コメントも使用可能
# Use English comments when appropriate
```

---

## AI Assistant Guidelines

### When Working with This Repository

#### 1. Language Considerations
- **Documentation**: Primarily Japanese, but English is acceptable
- **Code Comments**: Prefer Japanese to match existing patterns
- **Variable Names**: Mix of English and Japanese; follow file's existing style
- **Error Messages**: Use Japanese for user-facing messages

#### 2. Code Style Consistency
- **Always use `set -euo pipefail`** in shell scripts
- **Define constants with `readonly`**
- **Use color codes** for user-facing output (follow existing patterns)
- **Implement proper error handling** with trap and cleanup functions
- **Validate all inputs** before processing

#### 3. Script Creation Checklist
- [ ] Shebang line present (`#!/bin/bash`)
- [ ] Strict mode enabled (`set -euo pipefail`)
- [ ] Script header with description and version
- [ ] Constants defined at top
- [ ] Function organization with section markers
- [ ] Error handling implemented
- [ ] Help message (`--help` flag)
- [ ] Version information (`--version` flag)
- [ ] Input validation
- [ ] Proper exit codes
- [ ] Cleanup on exit

#### 4. Database Operations
- **Always backup before modifications**
- **Test queries on non-production first**
- **Use transactions for multi-statement operations**
- **Validate data integrity after operations**
- **Log all significant operations**

#### 5. Cloud Operations
- **Verify region/zone settings**
- **Check resource limits and quotas**
- **Implement retry logic with exponential backoff**
- **Use appropriate error handling**
- **Tag resources appropriately**

#### 6. Security Considerations
- **Never commit credentials or secrets**
- **Use environment variables for sensitive data**
- **Implement proper file permissions**
- **Validate and sanitize all inputs**
- **Use parameterized queries for SQL**
- **Follow principle of least privilege**

#### 7. File Modifications
- **Read existing files before modifying**
- **Maintain existing code style**
- **Add comments explaining changes**
- **Test changes before committing**
- **Update documentation if behavior changes**

#### 8. Testing Requirements
- **Test scripts with various inputs**
- **Verify error handling paths**
- **Check for memory/resource leaks**
- **Test with production-like data volumes**
- **Verify cleanup operations**

#### 9. Documentation Updates
- **Update README when adding new scripts**
- **Document all command-line options**
- **Provide usage examples**
- **Note any dependencies or prerequisites**
- **Document expected exit codes**

#### 10. Common Pitfalls to Avoid
- **Don't use `cd` without checking success**: Use absolute paths when possible
- **Don't parse `ls` output**: Use `find` or `glob` patterns
- **Don't ignore shellcheck warnings**: Fix or explicitly disable with justification
- **Don't hardcode paths**: Use variables and configuration
- **Don't assume user environment**: Check for required tools

### Example: Creating a New Utility Script

```bash
#!/bin/bash
set -euo pipefail

#
# データ処理ユーティリティ
# 作成日: 2025-12-02
# バージョン: 1.0
#
# CSVファイルを読み込み、指定されたフォーマットで出力します
#

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly SUPPORTED_FORMATS=("json" "xml" "sql")

# 色定義
readonly COLOR_ERROR='\033[1;31m'
readonly COLOR_SUCCESS='\033[1;32m'
readonly COLOR_RESET='\033[0m'

# ===== グローバル変数 =====
declare input_file=""
declare output_format="json"
declare output_file=""

# ===== ヘルパー関数 =====

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <入力ファイル>

CSVファイルを読み込み、指定されたフォーマットで変換します。

引数:
  <入力ファイル>         処理するCSVファイル

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -f, --format <形式>   出力形式 (json|xml|sql)
  -o, --output <ファイル> 出力ファイル (省略時は標準出力)

例:
  $PROG_NAME input.csv
  $PROG_NAME -f xml -o output.xml input.csv
EOF
}

error_exit() {
    echo -e "${COLOR_ERROR}エラー: $1${COLOR_RESET}" >&2
    exit 1
}

validate_format() {
    local format="$1"
    for supported in "${SUPPORTED_FORMATS[@]}"; do
        if [[ "$format" == "$supported" ]]; then
            return 0
        fi
    done
    error_exit "サポートされていない形式: $format"
}

# ===== メインロジック =====

process_csv() {
    local input="$1"
    local format="$2"
    local output="$3"

    # 処理ロジックをここに実装
    echo -e "${COLOR_SUCCESS}処理完了${COLOR_RESET}"
}

# ===== 引数解析 =====

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "$PROG_NAME version $VERSION"
                exit 0
                ;;
            -f|--format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"
                validate_format "$output_format"
                shift 2
                ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output には値が必要です"
                output_file="$2"
                shift 2
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                input_file="$1"
                shift
                ;;
        esac
    done

    # 必須引数チェック
    [[ -z "$input_file" ]] && error_exit "入力ファイルを指定してください"
    [[ ! -f "$input_file" ]] && error_exit "ファイルが見つかりません: $input_file"
}

# ===== メイン処理 =====

main() {
    parse_arguments "$@"
    process_csv "$input_file" "$output_format" "$output_file"
    exit 0
}

# スクリプト実行
main "$@"
```

---

## Version History

### Version 1.0.0 (2025-12-02)
- Initial CLAUDE.md creation
- Comprehensive repository analysis
- Documentation of coding conventions
- Development workflow guidelines
- AI assistant guidelines

---

## Contact and Support

For questions or issues related to this repository:
- Create an issue in the GitHub repository
- Review existing documentation in README.md files
- Check individual script help messages (`script.sh --help`)

---

## References

- Main README: `/home/user/My-infra/README.md`
- AWS Documentation: `/home/user/My-infra/AWS/readme.md`
- Database Documentation: `/home/user/My-infra/DB/Readme.md`
- Ansible Site Configuration: `/home/user/My-infra/site.yml`
- Example Timer Script: `/home/user/My-infra/Timer.sh`

---

**Note:** This document should be updated whenever significant changes are made to the repository structure, coding conventions, or development workflows.
