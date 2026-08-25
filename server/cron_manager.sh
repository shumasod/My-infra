#!/bin/bash
set -euo pipefail

#
# Cronジョブ管理ツール
# 作成日: 2026-08-25
# バージョン: 1.0
#
# cronジョブの一覧・追加・削除・テストを管理します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="list"
declare target_user=""
declare cron_expr=""
declare cron_cmd=""
declare job_label=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

cronジョブの管理ツールです。

コマンド:
  list [ユーザー]        cronジョブ一覧を表示
  add                    cronジョブを追加
  remove <番号>          cronジョブを削除
  test <cron式>          cron式を解析して次回実行時刻を表示
  log                    cronログを表示
  validate <cron式>      cron式の検証

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -u, --user <ユーザー>  対象ユーザー
  -e, --expr <cron式>    cron式 (例: "0 2 * * *")
  -c, --cmd <コマンド>   実行コマンド
  -l, --label <ラベル>   ジョブのラベル(コメント)

例:
  $PROG_NAME list
  $PROG_NAME list root
  $PROG_NAME add -e "0 2 * * *" -c "/path/to/backup.sh" -l "夜間バックアップ"
  $PROG_NAME remove 3
  $PROG_NAME test "*/5 * * * *"
  $PROG_NAME validate "0 25 * * *"
EOF
}

parse_cron_field() {
    local field="$1" min="$2" max="$3"
    if [[ "$field" == "*" ]]; then
        echo "毎"
        return
    fi
    if [[ "$field" =~ ^\*\/([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}毎"
        return
    fi
    if [[ "$field" =~ ^[0-9]+-[0-9]+$ ]]; then
        echo "${field}の範囲"
        return
    fi
    echo "$field"
}

describe_cron() {
    local expr="$1"
    read -r min hour dom mon dow <<< "$expr"

    local desc=""
    if [[ "$min" == "0" && "$hour" != "*" ]]; then
        desc="${hour}時00分"
    elif [[ "$min" =~ ^\*\/([0-9]+)$ ]]; then
        desc="${BASH_REMATCH[1]}分毎"
    else
        desc="分:$(parse_cron_field "$min" 0 59) 時:$(parse_cron_field "$hour" 0 23)"
    fi

    if [[ "$dom" != "*" ]]; then
        desc+=" 日:${dom}日"
    fi
    if [[ "$mon" != "*" ]]; then
        local mon_names=("" "1月" "2月" "3月" "4月" "5月" "6月" "7月" "8月" "9月" "10月" "11月" "12月")
        desc+=" ${mon_names[$mon]:-$mon月}"
    fi
    if [[ "$dow" != "*" ]]; then
        local dow_names=("日" "月" "火" "水" "木" "金" "土")
        desc+=" (${dow_names[$dow]:-?}曜日)"
    fi
    echo "$desc"
}

cmd_list() {
    local user="${1:-}"
    log_info "Cronジョブ一覧${user:+ (ユーザー: $user)}"
    echo ""

    local crontab_output
    if [[ -n "$user" ]]; then
        crontab_output=$(crontab -l -u "$user" 2>/dev/null || true)
    else
        crontab_output=$(crontab -l 2>/dev/null || true)
    fi

    if [[ -z "$crontab_output" ]]; then
        log_warning "cronジョブが登録されていません"
        echo ""
    else
        printf "${C_BOLD}【ユーザーcrontab】${C_RESET}\n\n"
        printf "${C_BOLD}  %3s  %-20s %-30s %s${C_RESET}\n" "#" "スケジュール" "説明" "コマンド"
        printf "  %s\n" "$(printf '%.0s─' {1..80})"

        local idx=0
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            (( idx++ ))
            local schedule cmd label=""

            if [[ "$line" =~ ^(@[a-z]+)[[:space:]]+(.*) ]]; then
                schedule="${BASH_REMATCH[1]}"
                cmd="${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^([0-9*,/-]+[[:space:]]+[0-9*,/-]+[[:space:]]+[0-9*,/-]+[[:space:]]+[0-9*,/-]+[[:space:]]+[0-9*,/-]+)[[:space:]]+(.*) ]]; then
                schedule="${BASH_REMATCH[1]}"
                cmd="${BASH_REMATCH[2]}"
            else
                continue
            fi

            local cron_fields
            read -r -a cron_fields <<< "$schedule"
            local desc=""
            if [[ ${#cron_fields[@]} -ge 5 ]]; then
                desc=$(describe_cron "${cron_fields[0]} ${cron_fields[1]} ${cron_fields[2]} ${cron_fields[3]} ${cron_fields[4]}")
            else
                desc="$schedule"
            fi

            local cmd_short="${cmd:0:45}"
            [[ ${#cmd} -gt 45 ]] && cmd_short+="..."

            printf "  ${C_CYAN}%3d${C_RESET}  %-20s %-30s ${C_DIM}%s${C_RESET}\n" \
                "$idx" "${schedule:0:20}" "$desc" "$cmd_short"
        done <<< "$crontab_output"
        echo ""
    fi

    printf "${C_BOLD}【システムcron (/etc/cron.d/)】${C_RESET}\n\n"
    if [[ -d /etc/cron.d ]]; then
        local found=false
        for f in /etc/cron.d/*; do
            [[ -f "$f" ]] || continue
            found=true
            printf "  ${C_YELLOW}%s${C_RESET}\n" "$(basename "$f")"
            grep -v '^#\|^$' "$f" 2>/dev/null | head -5 | while IFS= read -r line; do
                printf "    ${C_DIM}%s${C_RESET}\n" "$line"
            done
        done
        $found || printf "  ${C_DIM}(なし)${C_RESET}\n"
    fi
    echo ""

    for dir in hourly daily weekly monthly; do
        local dir_path="/etc/cron.${dir}"
        if [[ -d "$dir_path" ]]; then
            local count
            count=$(find "$dir_path" -maxdepth 1 -type f | wc -l)
            printf "  /etc/cron.%s: ${C_CYAN}%d${C_RESET} ジョブ\n" "$dir" "$count"
        fi
    done
    echo ""
}

cmd_add() {
    [[ -z "$cron_expr" ]] && error_exit "cron式を指定してください (-e)"
    [[ -z "$cron_cmd"  ]] && error_exit "コマンドを指定してください (-c)"

    cmd_validate "$cron_expr" || error_exit "無効なcron式です"

    local new_entry="$cron_expr $cron_cmd"
    [[ -n "$job_label" ]] && new_entry="# $job_label\n$new_entry"

    local current
    current=$(crontab -l 2>/dev/null || true)

    log_info "追加するジョブ:"
    echo "  スケジュール: $cron_expr"
    echo "  コマンド:     $cron_cmd"
    [[ -n "$job_label" ]] && echo "  ラベル:       $job_label"
    echo ""

    if ! confirm "このジョブを追加しますか？" "n"; then
        log_warning "キャンセルしました"
        return
    fi

    if [[ -n "$current" ]]; then
        printf "%s\n%b\n" "$current" "$new_entry" | crontab -
    else
        printf "%b\n" "$new_entry" | crontab -
    fi
    log_success "cronジョブを追加しました"
}

cmd_remove() {
    local target_idx="${1:-}"
    [[ -z "$target_idx" ]] && error_exit "削除する番号を指定してください"
    [[ ! "$target_idx" =~ ^[0-9]+$ ]] && error_exit "番号は整数で指定してください"

    local current
    current=$(crontab -l 2>/dev/null || true)
    [[ -z "$current" ]] && error_exit "cronジョブが登録されていません"

    local idx=0 new_crontab=""
    local removed_line=""
    while IFS= read -r line; do
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            new_crontab+="${line}\n"
            continue
        fi
        (( idx++ ))
        if [[ "$idx" == "$target_idx" ]]; then
            removed_line="$line"
        else
            new_crontab+="${line}\n"
        fi
    done <<< "$current"

    [[ -z "$removed_line" ]] && error_exit "番号 $target_idx のジョブが見つかりません"

    log_info "削除するジョブ: $removed_line"
    if ! confirm "このジョブを削除しますか？" "n"; then
        log_warning "キャンセルしました"
        return
    fi

    printf "%b" "$new_crontab" | crontab -
    log_success "cronジョブを削除しました (番号: $target_idx)"
}

cmd_test() {
    local expr="$1"
    log_info "cron式解析: $expr"
    echo ""

    cmd_validate "$expr" || return 1

    python3 - "$expr" <<'PYEOF'
import sys
from datetime import datetime, timedelta

expr = sys.argv[1]
parts = expr.strip().split()
if len(parts) != 5:
    print("エラー: cron式は5フィールド必要です")
    sys.exit(1)

min_f, hour_f, dom_f, mon_f, dow_f = parts

def matches(val, field, min_v, max_v):
    if field == '*': return True
    if '/' in field and field.startswith('*'):
        step = int(field.split('/')[1])
        return (val - min_v) % step == 0
    if '-' in field and '/' not in field:
        a, b = map(int, field.split('-'))
        return a <= val <= b
    if ',' in field:
        return val in [int(x) for x in field.split(',')]
    return val == int(field)

now = datetime.now().replace(second=0, microsecond=0)
results = []
t = now + timedelta(minutes=1)
for _ in range(525960):
    if (matches(t.minute, min_f, 0, 59) and
        matches(t.hour, hour_f, 0, 23) and
        matches(t.day, dom_f, 1, 31) and
        matches(t.month, mon_f, 1, 12) and
        matches(t.weekday() % 7, dow_f, 0, 6)):  # 0=日曜
        results.append(t)
        if len(results) >= 5:
            break
    t += timedelta(minutes=1)

print("次回実行予定時刻 (上位5件):\n")
for i, r in enumerate(results, 1):
    diff = r - now
    hours = int(diff.total_seconds() // 3600)
    mins  = int((diff.total_seconds() % 3600) // 60)
    print(f"  {i}. {r.strftime('%Y-%m-%d %H:%M')}  (約 {hours}時間{mins}分後)")
print()
PYEOF
}

cmd_validate() {
    local expr="$1"
    local fields
    read -r -a fields <<< "$expr"

    if [[ ${#fields[@]} -ne 5 ]]; then
        log_error "cron式は5フィールド必要です (分 時 日 月 曜日)"
        return 1
    fi

    local -A ranges=([0]="0 59" [1]="0 23" [2]="1 31" [3]="1 12" [4]="0 7")
    local -A names=([0]="分" [1]="時" [2]="日" [3]="月" [4]="曜日")
    local valid=true

    for i in "${!fields[@]}"; do
        local f="${fields[$i]}"
        local min max
        read -r min max <<< "${ranges[$i]}"
        if [[ "$f" == "*" ]]; then
            continue
        elif [[ "$f" =~ ^\*\/([0-9]+)$ ]]; then
            local step="${BASH_REMATCH[1]}"
            if (( step < 1 || step > max )); then
                log_error "${names[$i]}: ステップ値が範囲外です ($step)"
                valid=false
            fi
        elif [[ "$f" =~ ^[0-9]+$ ]]; then
            if (( f < min || f > max )); then
                log_error "${names[$i]}: 値が範囲外です ($f, 有効: $min-$max)"
                valid=false
            fi
        elif [[ "$f" =~ ^[0-9]+-[0-9]+$ ]]; then
            local a b
            IFS='-' read -r a b <<< "$f"
            if (( a < min || b > max || a > b )); then
                log_error "${names[$i]}: 範囲が無効です ($f)"
                valid=false
            fi
        elif [[ "$f" =~ ^[0-9,]+$ ]]; then
            :
        else
            log_error "${names[$i]}: 無効な値です ($f)"
            valid=false
        fi
    done

    if $valid; then
        log_success "有効なcron式です: $expr"
        return 0
    else
        return 1
    fi
}

cmd_log() {
    log_info "Cronログ"
    echo ""

    local log_files=("/var/log/cron" "/var/log/cron.log" "/var/log/syslog")
    local found=false

    for lf in "${log_files[@]}"; do
        if [[ -f "$lf" && -r "$lf" ]]; then
            found=true
            log_info "ログファイル: $lf"
            grep -i "cron\|CMD" "$lf" 2>/dev/null | tail -30 | while IFS= read -r line; do
                if echo "$line" | grep -qi "error\|fail"; then
                    printf "${C_RED}%s${C_RESET}\n" "$line"
                else
                    printf "${C_DIM}%s${C_RESET}\n" "$line"
                fi
            done
            break
        fi
    done

    if ! $found; then
        log_warning "cronログファイルが見つかりません"
        log_info "journalctl を試みます..."
        journalctl -u cron -u crond --no-pager -n 30 2>/dev/null || \
            log_warning "ログを取得できませんでした"
    fi
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        list|add|remove|test|log|validate)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -u|--user)    [[ $# -lt 2 ]] && error_exit "--user には値が必要です"; target_user="$2"; shift 2 ;;
            -e|--expr)    [[ $# -lt 2 ]] && error_exit "--expr には値が必要です"; cron_expr="$2"; shift 2 ;;
            -c|--cmd)     [[ $# -lt 2 ]] && error_exit "--cmd には値が必要です"; cron_cmd="$2"; shift 2 ;;
            -l|--label)   [[ $# -lt 2 ]] && error_exit "--label には値が必要です"; job_label="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        list)     cmd_list "${POSITIONAL[0]:-$target_user}" ;;
        add)      cmd_add ;;
        remove)   [[ ${#POSITIONAL[@]} -eq 0 ]] && error_exit "番号を指定してください"
                  cmd_remove "${POSITIONAL[0]}" ;;
        test)     [[ ${#POSITIONAL[@]} -eq 0 && -z "$cron_expr" ]] && error_exit "cron式を指定してください"
                  cmd_test "${POSITIONAL[0]:-$cron_expr}" ;;
        log)      cmd_log ;;
        validate) [[ ${#POSITIONAL[@]} -eq 0 && -z "$cron_expr" ]] && error_exit "cron式を指定してください"
                  cmd_validate "${POSITIONAL[0]:-$cron_expr}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
