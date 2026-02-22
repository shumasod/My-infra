# CLAUDE.md - AI Assistant Guide for My-infra Repository

**Last Updated:** 2026-02-13
**Version:** 2.0.0
**Repository:** My-infra - Infrastructure Automation & System Administration Toolkit

---

## Table of Contents

1. [Repository Overview](#repository-overview)
2. [Project Structure](#project-structure)
3. [Technology Stack](#technology-stack)
4. [Shared Library (lib/common.sh)](#shared-library-libcommonsh)
5. [Coding Conventions](#coding-conventions)
6. [Development Workflows](#development-workflows)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Git Practices](#git-practices)
9. [File Organization](#file-organization)
10. [Common Patterns](#common-patterns)
11. [Testing Guidelines](#testing-guidelines)
12. [Documentation Standards](#documentation-standards)
13. [AI Assistant Guidelines](#ai-assistant-guidelines)

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
- Interactive TUI (Text User Interface) applications
- Entertainment and educational shell-based tools

### Key Characteristics
- **Primary Language:** Bash/Shell scripts (192 files, ~50% of codebase)
- **Version:** 2.0.0
- **License:** MIT
- **Documentation Language:** Primarily Japanese
- **Maturity:** Active development with frequent commits (282+ merged PRs)
- **Target Users:** IT professionals, system administrators, DevOps engineers
- **Shared Library:** `lib/common.sh` provides reusable utilities across scripts

### Repository Statistics
- **Total Files:** 384+
- **Total Directories:** 77
- **Languages:** 12+ (Bash, SQL, Python, PowerShell, Go, JavaScript, Java, Haskell, BASIC, YAML, etc.)
- **Database Systems:** 6 (MySQL, PostgreSQL, MongoDB, Redis/Valkey, DynamoDB, Oracle)
- **Cloud Providers:** AWS, Google Cloud Platform
- **CI/CD:** GitHub Actions (security tests pipeline)

---

## Project Structure

### Root Level Organization

```
/home/user/My-infra/
├── .github/workflows/      # GitHub Actions CI/CD pipelines
│
│   ── Infrastructure & Cloud ──
├── AWS/                    # Amazon Web Services automation (EC2, ALB, SSO, Terraform)
├── Google/                 # Google Cloud services, GAS (Google Apps Scripts)
├── Bigquery/              # BigQuery data warehouse management
├── deploy/                # Deployment automation scripts
│
│   ── Databases ──
├── DB/                    # Cross-database tools (MySQL, PostgreSQL, backup/restore)
├── DynamoDB/              # AWS DynamoDB management
├── MongoDB/               # MongoDB documentation & tools
├── mysql/                 # MySQL utilities, Docker configs, batch tools
├── redis/                 # Redis configuration
├── Valkey/                # Valkey cluster management (Ansible)
│
│   ── System Administration ──
├── server/                # Server management (SSH, monitoring, backups, disk)
├── network/               # Network infrastructure & testing
├── network_tool/          # TUI-based network programming tools
├── security/              # Security validation & policy enforcement
├── pc/                    # Windows PC management (PowerShell)
│
│   ── Shared Libraries & Utilities ──
├── lib/                   # Shared utility library (common.sh)
├── utils/                 # General utilities (Timer, MCP, Quiz, Monitor, M1)
├── scripts/               # General-purpose scripts (testing, scoring, etc.)
├── Validation/            # Input validators (Luhn, email, phone, password)
│
│   ── Entertainment & Interactive ──
├── Asobi/                 # Entertainment scripts (45+ scripts: ASCII art, games, music)
├── chat/                  # Shell-based group chat system (server/client/GUI)
├── karaoke/               # Karaoke system with song library (36+ songs)
├── kawaii/                 # Interactive "kawaii" judgment system
├── marathon/              # 24-hour TV-style 100km marathon simulator
├── restaurant/            # Dynamic restaurant intro page generator
├── game/                  # Educational games and utilities
│
│   ── Data & Content ──
├── data/                  # Data processing files (Go, shell)
├── art/                   # ASCII art scripts (ninja, train)
├── query/                 # SQL query examples (1.sql - 5.sql)
├── awk/                   # AWK programming examples
│
│   ── Other ──
├── assign/                # Environment configuration
├── http/                  # HTTP monitoring
├── work/                  # Workflow automation
├── week/                  # Weekly scheduling
├── 2025/                  # Calendar/scheduling
├── tests/                 # Test suite (BATS security tests, Python tests)
├── Basic/                 # BASIC programming examples
├── Haskell/               # Haskell programming examples
│
│   ── Root Files ──
├── CLAUDE.md              # This file - AI assistant guide
├── README.md              # Main documentation (Japanese)
├── SECURITY_TESTING_REPORT.md  # Security testing report
├── site.yml               # Ansible playbook (Valkey cluster)
├── inventory.ini          # Ansible inventory
└── dockerfile             # Docker configuration
```

### Domain-Specific Directories

#### Infrastructure & Cloud
- **AWS/**: EC2 management, ALB configs, auto-scaling, SSO, CLI scripts, Terraform modules
- **Google/**: GAS (Google Apps Scripts), Cloud services
- **Bigquery/**: Dataset operations, query management
- **deploy/**: Deployment automation scripts

#### Databases
- **DB/**: Cross-database tools (MySQL, PostgreSQL, backup/restore, PDF-to-Excel conversion)
- **MongoDB/**: MongoDB utilities, SQL examples
- **mysql/**: MySQL backup, Docker configs, batch tools
- **redis/**, **Valkey/**: Redis/Valkey configurations and cluster setup (Ansible-managed)
- **DynamoDB/**: AWS DynamoDB management

#### System Administration
- **server/**: SSH management, monitoring, backups, disk management, daily DB backups
- **network/**: Network testing, subnet calculations
- **network_tool/**: TUI-based interactive network programming tools
- **security/**: Input validation, security policy enforcement
- **pc/**: Windows management scripts (PowerShell), auto-provisioning

#### Shared Libraries & Utilities
- **lib/**: Shared common library (`common.sh`) — colors, logging, terminal control, progress bars
- **utils/**: Standalone utilities (Timer, MCP animation, Quiz, Monitor, M1 scoring)
- **scripts/**: General-purpose scripts (frozen, mensetu, scoring, test runners)
- **Validation/**: Input validators (Luhn algorithm, email, phone, password)

#### Entertainment & Interactive
- **Asobi/**: 45+ entertainment scripts (ASCII art, music, games, quizzes, fortune-telling)
- **chat/**: Shell-based group chat with server/client architecture and GUI
- **karaoke/**: Karaoke system with dynamic song library (demo, 80s-90s J-pop, enka)
- **kawaii/**: Interactive attractiveness judgment system
- **marathon/**: 24-hour TV marathon simulation
- **restaurant/**: Dynamic restaurant page generator (shell-script-based content generation)
- **game/**: Educational games and utilities

#### Testing
- **tests/security/**: BATS security tests and Python input validation tests
- **.github/workflows/**: CI/CD pipeline for automated security testing

---

## Technology Stack

### Primary Technologies

| Technology | Usage | File Count |
|-----------|-------|------------|
| Bash/Shell | Infrastructure automation, TUI apps, entertainment | 192 |
| Text | Song lyrics, configuration data | 30 |
| SQL | Database queries, schema management | 19 |
| Markdown | Documentation | 18 |
| YAML | Ansible playbooks, CI/CD, configuration | 8 |
| PureScript-like (.psl) | Utility functions | 6 |
| Python | Data processing, security testing | 5 |
| PowerShell | Windows PC management | 4 |
| BASIC | Educational programming examples | 3 |
| BATS | Bash Automated Testing System | 2 |
| JavaScript | GAS automation | 2 |
| Go | High-performance data processing | 1 |
| Java | Validation tools | 1 |
| Haskell | Functional programming examples | 1 |

### Infrastructure Tools
- **Container Orchestration:** Docker, Docker Compose
- **Configuration Management:** Ansible
- **Infrastructure as Code:** Terraform
- **Version Control:** Git
- **CI/CD:** GitHub Actions

### Cloud Platforms
- **AWS:** EC2, ALB, DynamoDB, Elasticache, RDS, Auto-scaling, SSO
- **Google Cloud:** BigQuery, Sheets API, Google Apps Scripts

### Databases
- **Relational:** MySQL/MariaDB, PostgreSQL, Oracle DB
- **NoSQL:** MongoDB, DynamoDB
- **Cache/Key-Value:** Redis, Valkey

### Testing Tools
- **BATS:** Bash Automated Testing System for shell script testing
- **pytest:** Python test framework for input validation tests
- **ShellCheck:** Static analysis for shell scripts
- **gitleaks:** Credential leak detection
- **Trivy:** Dependency vulnerability scanning
- **Bandit:** Python security analysis

---

## Shared Library (lib/common.sh)

The repository includes a shared utility library at `lib/common.sh` that provides reusable functions across scripts. New scripts should use this library to reduce code duplication.

### How to Source

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
```

The library includes a double-load prevention guard (`_COMMON_SH_LOADED`).

### Available Features

#### Color Constants
- **Reset/Style:** `C_RESET`, `C_BOLD`, `C_DIM`, `C_ITALIC`, `C_UNDERLINE`, `C_BLINK`, `C_REVERSE`
- **Foreground (bold):** `C_BLACK`, `C_RED`, `C_GREEN`, `C_YELLOW`, `C_BLUE`, `C_MAGENTA`, `C_CYAN`, `C_WHITE`
- **Bright foreground:** `C_BRIGHT_RED`, `C_BRIGHT_GREEN`, `C_BRIGHT_YELLOW`, `C_BRIGHT_BLUE`, `C_BRIGHT_MAGENTA`, `C_BRIGHT_CYAN`
- **Background:** `C_BG_BLACK`, `C_BG_RED`, `C_BG_GREEN`, `C_BG_YELLOW`, `C_BG_BLUE`, `C_BG_MAGENTA`, `C_BG_CYAN`, `C_BG_WHITE`, `C_BG_GRAY`
- **User color palette:** `USER_COLOR_PALETTE` array (12 colors for chat/multi-user systems)

#### Terminal Functions
- `update_terminal_size` — Updates `TERM_ROWS` and `TERM_COLS` globals
- `clear_screen` — Clears the terminal
- `move_cursor ROW COL` — Positions cursor
- `clear_line` — Clears current line
- `hide_cursor` / `show_cursor` — Cursor visibility control
- `draw_separator ROW [CHAR]` — Draws horizontal separator line

#### Text Display
- `print_center TEXT [ROW] [COLOR]` — Center-aligned text output
- `print_right TEXT [ROW] [COLOR]` — Right-aligned text output

#### Logging
- `log_info MSG` — Info-level log (cyan)
- `log_success MSG` — Success log (green)
- `log_warning MSG` — Warning log (yellow)
- `log_error MSG` — Error log to stderr (red)
- `log_debug MSG` — Debug log (only when `DEBUG=1`)
- `error_exit MSG [CODE]` — Log error and exit

#### Time/Date
- `format_time SECONDS` — Format as `HH:MM:SS`
- `format_time_short SECONDS` — Format as `MM:SS`
- `get_timestamp` — Returns `YYYY-MM-DD HH:MM:SS`
- `get_current_year` — Returns current year

#### Utilities
- `get_user_color NAME` — Deterministic color from username hash
- `confirm MSG [DEFAULT]` — Interactive Y/N prompt
- `draw_progress_bar CURRENT TOTAL [WIDTH]` — Visual progress bar
- `show_spinner` — Animated spinner for background processes
- `with_file_lock LOCKFILE COMMAND...` — flock-based file locking

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

#### Using the Common Library
For scripts that need colors, logging, terminal control, or progress indicators, source the shared library instead of redefining constants:

```bash
#!/bin/bash
set -euo pipefail

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# lib/common.sh の関数を使用
log_info "処理を開始します"
draw_progress_bar 50 100
log_success "処理が完了しました"
```

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

For scripts that do NOT source `lib/common.sh`, define colors locally:

```bash
readonly COLOR_TITLE='\033[1;36m'    # シアン（太字）
readonly COLOR_TIME='\033[1;32m'     # 緑（太字）
readonly COLOR_PROGRESS='\033[1;33m' # 黄色（太字）
readonly COLOR_ERROR='\033[1;31m'    # 赤（太字）
readonly COLOR_SUCCESS='\033[1;32m'  # 緑（太字）
readonly COLOR_RESET='\033[0m'       # リセット
```

For scripts that DO source `lib/common.sh`, use the `C_*` constants instead (e.g., `C_RED`, `C_GREEN`, `C_RESET`).

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
   - Backup automation (`server/dailyDbBackup.sh`)
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

### Interactive/TUI Application Development

New TUI-based and interactive scripts should:
1. Source `lib/common.sh` for shared terminal functions
2. Use `hide_cursor` / `show_cursor` for clean TUI experience
3. Implement `trap cleanup EXIT` to restore terminal state
4. Use `update_terminal_size` to adapt to terminal dimensions
5. Use `draw_separator`, `print_center`, `move_cursor` for layout

```bash
#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

cleanup() {
    show_cursor
    clear_screen
}
trap cleanup EXIT

hide_cursor
update_terminal_size
clear_screen

# TUI rendering loop
while true; do
    print_center "タイトル" 1 "$C_CYAN"
    draw_separator 2
    # ...
    read -rsn1 key
done
```

---

## CI/CD Pipeline

### GitHub Actions Security Tests

The repository has a CI/CD pipeline at `.github/workflows/security-tests.yml` that runs on:
- **Push** to `main`, `master`, and `claude/**` branches
- **Pull requests** to `main` and `master`
- **Scheduled** daily at 03:00 UTC (12:00 JST)
- **Manual dispatch** via `workflow_dispatch`

### Pipeline Jobs

| Job | Description | Tools |
|-----|-------------|-------|
| credential-scan | 認証情報漏洩スキャン | BATS, gitleaks |
| shellcheck | シェルスクリプト静的解析 | shellcheck |
| command-injection-tests | コマンドインジェクション検査 | BATS |
| python-security-tests | Python入力検証テスト | pytest, Bandit, Safety |
| dependency-scan | 依存関係脆弱性スキャン | Trivy |
| owasp-dependency-check | OWASP依存関係チェック (scheduled/manual only) | OWASP Dependency-Check |
| security-summary | テスト結果サマリー | — |

### Critical Directories for ShellCheck
The CI pipeline runs shellcheck on these directories with `--severity=warning`:
- `DB/`, `deploy/`, `server/`, `security/`, `AWS/`

---

## Git Practices

### Branch Strategy

The repository uses:
- **Main/Master branch**: Production-ready code
- **Feature branches**: Named with descriptive labels (e.g., `feature/35`, `feature/119`)
- **Claude branches**: AI-assisted work uses `claude/` prefix (e.g., `claude/network-programming-gui-CBtuM`)

### Commit Message Conventions

The repository follows conventional commit format:

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

**Recent examples from commit history:**
```
feat: TUIベースのネットワークプログラミングツールを追加
feat: カラオケ機能を追加
refactor: 共通ユーティリティライブラリを作成しコード重複を削減
fix: 複数のセキュリティ脆弱性を修正
```

### Pull Request Process

1. Create feature branch from main
2. Implement changes with appropriate tests
3. Update relevant documentation
4. Create PR with descriptive title and body
5. Address review feedback
6. Merge after approval

The repository has 282+ merged PRs and uses a rapid merge cadence.

---

## File Organization

### Naming Conventions

#### Shell Scripts
- Use lowercase with underscores: `db_backup.sh`, `daily_db_backup.sh`
- Descriptive names indicating purpose: `ec2_ssh_check1.sh`
- Version suffixes when applicable: `test1.sh`, `test2.sh`
- Japanese names allowed for entertainment scripts: `赤ちゃんベイビー.sh`, `喧嘩.sh`

#### Configuration Files
- Use descriptive names: `inventory.ini`, `site.yml`
- Include context: `docker-compose.yml`

#### Song/Data Files
- Text files for karaoke: `karaoke/songs/*.txt`
- Descriptive names for data: `data/data.go`

#### Documentation
- Use README.md for directory documentation
- Specific docs use descriptive names: `AboutDomain.md`, `scal.md`

### Directory Structure Rules

1. **Functional Grouping**: Scripts are organized by technology/purpose
2. **Flat Structure**: Most directories are single-level
3. **Subdirectories**: Used for complex modules (e.g., `karaoke/songs/`, `folder/Docker/`)
4. **Separation of Concerns**: Infrastructure, utilities, entertainment, and tests are in separate directories
5. **Shared Code**: Common utilities live in `lib/` and are sourced by other scripts

### Recent Reorganization (Since Dec 2025)

Many root-level scripts were moved into organized subdirectories:
- `Timer.sh`, `MCP.sh`, `Quiz.sh`, `M1.sh` → `utils/`
- Entertainment scripts → `Asobi/`
- Network scripts → `network/`
- Validation scripts → `Validation/`
- Data files → `data/`
- PC management → `pc/`
- General scripts → `scripts/`
- AWS-specific scripts → `AWS/`

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

### TUI Application Pattern (New)

```bash
#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

# クリーンアップ処理
cleanup() {
    show_cursor
    printf '\033[?1049l'  # メインスクリーン復帰
}
trap cleanup EXIT INT TERM

# 初期化
printf '\033[?1049h'  # 代替スクリーンバッファ
hide_cursor
update_terminal_size

# メインループ
while true; do
    clear_screen
    print_center "アプリケーション名" 1 "$C_CYAN"
    draw_separator 2

    # コンテンツ描画
    move_cursor 4 2
    echo -ne "${C_GREEN}メニュー項目${C_RESET}"

    # キー入力処理
    read -rsn1 key
    case "$key" in
        q|Q) break ;;
        # ...
    esac
done
```

### Chat/Server-Client Pattern (New)

```bash
#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# ファイルロックを使用した安全なメッセージ書き込み
send_message() {
    local chat_file="$1"
    local username="$2"
    local message="$3"
    local timestamp
    timestamp=$(get_timestamp)

    with_file_lock "${chat_file}.lock" \
        bash -c "echo '${timestamp}|${username}|${message}' >> '${chat_file}'"
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

2. **BATS Testing**
   The repository uses BATS (Bash Automated Testing System) for security tests:
   ```bash
   # テストの実行
   bats tests/security/test_credential_exposure.bats
   bats tests/security/test_command_injection.bats
   ```

3. **Unit Testing**
   - Test individual functions with various inputs
   - Verify error handling
   - Check edge cases

4. **Integration Testing**
   - Test script with real resources (use test environment)
   - Verify backup/restore cycles
   - Test with different configurations

### Python Testing

```bash
# セキュリティ入力検証テストの実行
python -m pytest tests/security/test_input_validation.py -v --tb=short

# Bandit セキュリティスキャン
bandit -r . -ll --exclude ./tests,./venv
```

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
- **Commit Messages**: Use Japanese descriptions with conventional commit prefixes (e.g., `feat: カラオケ機能を追加`)

#### 2. Code Style Consistency
- **Always use `set -euo pipefail`** in shell scripts
- **Define constants with `readonly`**
- **Source `lib/common.sh`** for colors, logging, and terminal control in new scripts
- **Use color codes** for user-facing output (follow existing patterns)
- **Implement proper error handling** with trap and cleanup functions
- **Validate all inputs** before processing

#### 3. Script Creation Checklist
- [ ] Shebang line present (`#!/bin/bash`)
- [ ] Strict mode enabled (`set -euo pipefail`)
- [ ] Script header with description and version
- [ ] Source `lib/common.sh` if using colors/logging/terminal functions
- [ ] Constants defined at top
- [ ] Function organization with section markers
- [ ] Error handling implemented
- [ ] Help message (`--help` flag)
- [ ] Version information (`--version` flag)
- [ ] Input validation
- [ ] Proper exit codes
- [ ] Cleanup on exit (especially for TUI apps — restore cursor, screen)

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
- **Be aware of CI/CD security scanning** — code pushed to `claude/**` branches triggers security tests

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
- **Run `shellcheck` on critical scripts** before committing

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
- **Don't redefine common.sh functions**: Source the library instead
- **Don't forget cleanup in TUI apps**: Always restore cursor and terminal state

#### 11. Directory Placement Guide

When creating new scripts, place them in the appropriate directory:

| Script Type | Directory |
|------------|-----------|
| AWS automation | `AWS/` |
| Database tools | `DB/` |
| Server management | `server/` |
| Network tools | `network/` or `network_tool/` |
| Security scripts | `security/` |
| Input validators | `Validation/` |
| General utilities | `utils/` |
| Entertainment/games | `Asobi/` |
| Interactive TUI apps | Appropriate domain dir or new dir |
| Shared library functions | `lib/common.sh` |
| Test scripts | `tests/` |
| General-purpose scripts | `scripts/` |

### Example: Creating a New Utility Script

```bash
#!/bin/bash
set -euo pipefail

#
# データ処理ユーティリティ
# 作成日: 2026-02-13
# バージョン: 1.0
#
# CSVファイルを読み込み、指定されたフォーマットで出力します
#

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly SUPPORTED_FORMATS=("json" "xml" "sql")

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

    log_info "処理を開始: $input (形式: $format)"
    # 処理ロジックをここに実装
    log_success "処理完了"
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

### Version 2.0.0 (2026-02-13)
- Updated repository statistics (384+ files, 77 directories, 192 shell scripts)
- Added documentation for shared library `lib/common.sh`
- Added CI/CD pipeline documentation (GitHub Actions security tests)
- Updated project structure to reflect major reorganization (scripts moved to subdirectories)
- Added new directories: `Asobi/`, `chat/`, `karaoke/`, `kawaii/`, `lib/`, `marathon/`, `network_tool/`, `restaurant/`, `scripts/`, `utils/`, `data/`, `art/`, `tests/`
- Added TUI application development pattern
- Added Chat/Server-Client pattern
- Added BATS and Python security testing documentation
- Added directory placement guide for AI assistants
- Updated commit message conventions to reflect actual usage
- Updated references to reflect moved files

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
- Shared Library: `/home/user/My-infra/lib/common.sh`
- AWS Documentation: `/home/user/My-infra/AWS/readme.md`
- Database Documentation: `/home/user/My-infra/DB/Readme.md`
- Ansible Site Configuration: `/home/user/My-infra/site.yml`
- CI/CD Pipeline: `/home/user/My-infra/.github/workflows/security-tests.yml`
- Security Report: `/home/user/My-infra/SECURITY_TESTING_REPORT.md`
- Security Tests: `/home/user/My-infra/tests/security/`
- Timer Utility: `/home/user/My-infra/utils/Timer.sh`
- Quiz Utility: `/home/user/My-infra/utils/Quiz.sh`

---

**Note:** This document should be updated whenever significant changes are made to the repository structure, coding conventions, or development workflows.
