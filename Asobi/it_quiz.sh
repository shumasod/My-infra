#!/bin/bash
set -euo pipefail

#
# IT知識クイズ
# バージョン: 1.0
#
# インフラ・ネットワーク・セキュリティ・Linuxに関するクイズゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare category="all"
declare difficulty="normal"
declare -i question_count=10
declare -i time_limit=30

# クイズデータ: "問題|A:選択肢A|B:選択肢B|C:選択肢C|D:選択肢D|正解|解説"
declare -a QUESTIONS_LINUX=(
    "Linuxでファイルの権限を変更するコマンドは?|A:chown|B:chmod|C:chgrp|D:chattr|B|chmodはCHange MODeの略。chownは所有者変更、chgrpはグループ変更。"
    "プロセスにシグナル15(SIGTERM)を送るコマンドは?|A:kill -9 PID|B:kill -15 PID|C:kill -1 PID|D:kill PID|D|killコマンドのデフォルトシグナルはSIGTERM(15)。-9はSIGKILLで強制終了。"
    "/etc/passwdファイルに含まれないフィールドは?|A:ユーザー名|B:パスワード(暗号化)|C:UID|D:ホームディレクトリ|B|現代のLinuxではパスワードは/etc/shadowに保存。/etc/passwdの2番目フィールドはxプレースホルダー。"
    "Linuxで現在のディスク使用量を確認するコマンドは?|A:df|B:du|C:ls -s|D:free|A|dfはDisk Freeの略でファイルシステム全体の使用量。duはDisk Usageで個々のディレクトリサイズ。"
    "シンボリックリンクを作成するコマンドは?|A:ln file link|B:ln -s file link|C:link file link|D:mklink file link|B|ln -sの-sがsymbolic(シンボリック)を意味する。-sなしはハードリンク。"
    "Linuxのiノード(inode)に含まれないのは?|A:ファイルサイズ|B:ファイル名|C:作成日時|D:パーミッション|B|ファイル名はディレクトリエントリに保存。inodeにはメタデータ(サイズ・権限・タイムスタンプ等)が含まれる。"
    "crontab -eコマンドの役割は?|A:cronを削除する|B:cronログを表示する|C:cronジョブを編集する|D:cronサービスを再起動する|C|crontab -eでエディタが開きスケジュールを編集できる。-lで一覧、-rで削除。"
    "Linuxでファイルの最後の10行を表示するコマンドは?|A:head|B:tail|C:cat|D:less|B|tailはファイルの末尾を表示。デフォルトは10行。-fオプションでリアルタイム追跡。"
    "環境変数PATHの役割は?|A:カレントディレクトリ|B:コマンド検索パスの一覧|C:Pythonのパス|D:ログファイルの場所|B|シェルがコマンドを探すディレクトリをコロン区切りで指定。whichコマンドはPATHを使って検索。"
    "umask 022のデフォルトファイル権限は?|A:644|B:755|C:777|D:600|A|umask022はファイル(666)から022を引いて644、ディレクトリ(777)から022を引いて755。"
)

declare -a QUESTIONS_NETWORK=(
    "OSIモデルの第3層(ネットワーク層)のプロトコルは?|A:TCP|B:UDP|C:IP|D:HTTP|C|IPはInternet Protocol。第3層でルーティングを担当。TCPとUDPは第4層(トランスポート層)。"
    "デフォルトゲートウェイの役割は?|A:DNSサーバー|B:別ネットワークへのパケット転送先|C:DHCPサーバー|D:ファイアウォール|B|デフォルトゲートウェイは宛先不明パケットを転送するルーター。"
    "TCP 3ウェイハンドシェイクの正しい順序は?|A:SYN→ACK→SYN-ACK|B:SYN→SYN-ACK→ACK|C:ACK→SYN→SYN-ACK|D:SYN-ACK→SYN→ACK|B|SYN(クライアント)→SYN-ACK(サーバー)→ACK(クライアント)でTCP接続確立。"
    "HTTPSのデフォルトポート番号は?|A:80|B:8080|C:443|D:8443|C|HTTP=80、HTTPS=443。8080と8443は代替ポートとして使われることが多い。"
    "サブネットマスク255.255.255.0のCIDR表記は?|A:/8|B:/16|C:/24|D:/32|C|255.255.255.0は2進数で11111111.11111111.11111111.00000000 = 24ビット。"
    "DNSのAAAAレコードは何を示す?|A:メールサーバー|B:IPv6アドレス|C:別名(エイリアス)|D:テキスト情報|B|Aレコード=IPv4アドレス、AAAAレコード=IPv6アドレス。"
    "NATとは何か?|A:ネットワーク認証技術|B:プライベートIPをグローバルIPに変換する技術|C:暗号化プロトコル|D:ルーティングアルゴリズム|B|Network Address Translation。IPv4アドレス枯渇対策として広く使われる。"
    "TCPとUDPの違いとして正しいのは?|A:UDPは接続確立が必要|B:TCPは再送制御なし|C:UDPはリアルタイム通信向き|D:TCPは順序保証なし|C|UDPはオーバーヘッドが少なく速い。動画・音声・ゲームなどリアルタイム性重視の用途に適する。"
    "BGP(Border Gateway Protocol)の用途は?|A:LAN内ルーティング|B:AS間のルーティング|C:VPN暗号化|D:DNSキャッシュ|B|BGPはインターネットのAS(自律システム)間でのルーティング情報交換に使われる。"
    "pingコマンドが使うプロトコルは?|A:TCP|B:UDP|C:ICMP|D:ARP|C|PingはICMP Echo Request/Replyを使用。ICMPはInternet Control Message Protocol。"
)

declare -a QUESTIONS_SECURITY=(
    "SQLインジェクション対策として最も効果的なのは?|A:エラーメッセージを隠す|B:プリペアドステートメントを使う|C:ファイアウォールを設置する|D:HTTPSを使う|B|プリペアドステートメント(パラメータ化クエリ)でSQLを事前にコンパイルしてインジェクションを防ぐ。"
    "XSS(クロスサイトスクリプティング)の対策は?|A:SQLサニタイジング|B:出力のHTMLエスケープ|C:HTTPS化|D:ファイアウォール|B|ユーザー入力をHTML出力する際に<>&等を実体参照に変換してスクリプト実行を防ぐ。"
    "CSRF攻撃の対策として有効なのは?|A:入力値バリデーション|B:CSRFトークンの使用|C:パスワードハッシュ化|D:TLS証明書|B|CSRFトークンは各リクエストにサーバー生成のランダム値を含め、正規サイトからのリクエストのみ受け付ける。"
    "パスワードのハッシュ化で推奨されるアルゴリズムは?|A:MD5|B:SHA-1|C:bcrypt|D:Base64|C|bcryptは意図的に低速で計算コストを調整できる。MD5・SHA-1は衝突リスクがありパスワード保存に不適。"
    "TLS(Transport Layer Security)が提供しない機能は?|A:暗号化|B:認証|C:完全性|D:可用性|D|TLSは機密性(暗号化)・完全性・認証を提供するが、可用性(Availability)はDDoS対策など別の仕組みが必要。"
    "最小権限の原則(PoLP)の意味は?|A:パスワードを最小文字数にする|B:必要最小限の権限のみ付与する|C:ユーザー数を最小にする|D:ログを最小化する|B|Principle of Least Privilege。必要以上の権限を与えないことで攻撃被害の範囲を最小化。"
    "ゼロデイ脆弱性とは?|A:深刻度がゼロの脆弱性|B:公開からパッチまでの期間がゼロ(パッチ未提供)の脆弱性|C:0番ポートの脆弱性|D:削除済みの脆弱性|B|ベンダーがまだ把握または修正できていない脆弱性。攻撃者に有利な状況。"
    "DoS攻撃とDDoS攻撃の違いは?|A:DDoSはDBを狙う|B:DDoSは複数拠点から攻撃する|C:DoSは暗号化を使う|D:違いはない|B|DDoS(Distributed DoS)はボットネット等の多数のホストから一斉に攻撃するため対策が難しい。"
    "PKI(公開鍵インフラ)での認証局(CA)の役割は?|A:パスワード管理|B:デジタル証明書の発行・管理|C:VPN接続|D:ファイアウォール管理|B|CAはデジタル証明書を発行・管理し、公開鍵と所有者の結びつきを保証する。"
    "ソーシャルエンジニアリングの例として正しいのは?|A:SQLインジェクション|B:フィッシングメール|C:バッファオーバーフロー|D:総当たり攻撃|B|ソーシャルエンジニアリングは技術でなく人間の心理を騙す手法。フィッシング・電話詐欺など。"
)

declare -a QUESTIONS_INFRA=(
    "Dockerコンテナとバーチャルマシン(VM)の主な違いは?|A:コンテナはOSを共有する|B:VMの方が起動が速い|C:コンテナは分離性が高い|D:VMはイメージが小さい|A|コンテナはホストOSのカーネルを共有するため軽量。VMはゲストOSを持つため隔離性が高いが重い。"
    "Kubernetesのポッド(Pod)の説明として正しいのは?|A:物理サーバー|B:1つ以上のコンテナのグループ|C:ネットワーク設定|D:ストレージボリューム|B|PodはKubernetesの最小デプロイ単位。同じPod内のコンテナはネットワーク・ストレージを共有。"
    "Infrastructure as Code(IaC)のツールは?|A:Ansible・Terraform|B:Docker・Kubernetes|C:Nginx・Apache|D:MySQL・PostgreSQL|A|IaCはインフラをコードで管理するアプローチ。TerraformはプロビジョニングAnsibleは構成管理に使われる。"
    "CI/CDパイプラインのCIが意味するのは?|A:Continuous Improvement|B:Continuous Integration|C:Container Instance|D:Cloud Infrastructure|B|CI(継続的インテグレーション)はコード変更を頻繁にマージしてビルド・テストを自動実行する手法。"
    "ブルーグリーンデプロイメントの目的は?|A:メモリ使用量削減|B:ゼロダウンタイムデプロイ|C:セキュリティ強化|D:コスト削減|B|Blue(現行)とGreen(新バージョン)環境を並行稼働させ、ルーティングを切り替えることでダウンタイムゼロを実現。"
    "Ansibleの接続方式のデフォルトは?|A:エージェントインストール|B:SSH|C:WinRM|D:SNMP|B|AnsibleはエージェントレスでSSH経由で管理対象に接続。Windows管理にはWinRMを使用。"
    "オートスケーリングの目的は?|A:手動でサーバーを追加する|B:負荷に応じてサーバー数を自動調整する|C:データを自動バックアップする|D:ログを自動削除する|B|負荷が高い時にサーバーを自動追加(スケールアウト)、低い時に削除(スケールイン)してコストと性能を最適化。"
    "RTO(Recovery Time Objective)とは?|A:データ損失の許容量|B:復旧までの目標時間|C:バックアップ頻度|D:サービス稼働率|B|RPO(Recovery Point Objective)はデータ損失の許容量(時間)。RTO+RPOで可用性要件を定義する。"
    "ロードバランサーのラウンドロビン方式は?|A:負荷が最小のサーバーに振り分ける|B:順番に各サーバーに振り分ける|C:最初のサーバーに常に振り分ける|D:ランダムに振り分ける|B|ラウンドロビンはサーバーに均等に順番で振り分ける最もシンプルな方式。"
    "マイクロサービスアーキテクチャの特徴は?|A:単一の大きなアプリケーション|B:機能ごとに独立したサービスに分割|C:データベースを共有しない|D:BとCの両方|D|マイクロサービスは機能単位で独立デプロイ可能なサービスに分割し、サービス毎にDBを持つことが推奨される。"
)

get_questions() {
    case "$category" in
        linux)    printf '%s\n' "${QUESTIONS_LINUX[@]}" ;;
        network)  printf '%s\n' "${QUESTIONS_NETWORK[@]}" ;;
        security) printf '%s\n' "${QUESTIONS_SECURITY[@]}" ;;
        infra)    printf '%s\n' "${QUESTIONS_INFRA[@]}" ;;
        all)
            printf '%s\n' "${QUESTIONS_LINUX[@]}"
            printf '%s\n' "${QUESTIONS_NETWORK[@]}"
            printf '%s\n' "${QUESTIONS_SECURITY[@]}"
            printf '%s\n' "${QUESTIONS_INFRA[@]}"
            ;;
    esac
}

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

IT知識クイズ

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -c, --category CAT      カテゴリ (linux|network|security|infra|all) [デフォルト: all]
  -n, --count NUM         問題数 [デフォルト: 10]
  -t, --time SEC          制限時間(秒/問) [デフォルト: 30]

例:
  $PROG_NAME
  $PROG_NAME -c linux -n 5
  $PROG_NAME -c security -t 45

EOF
}

play_quiz() {
    local -a all_questions=()
    mapfile -t all_questions < <(get_questions)

    # シャッフル
    local n=${#all_questions[@]}
    for (( i=n-1; i>0; i-- )); do
        local j=$(( RANDOM % (i+1) ))
        local tmp="${all_questions[$i]}"
        all_questions[$i]="${all_questions[$j]}"
        all_questions[$j]="$tmp"
    done

    local total=$(( question_count < n ? question_count : n ))
    local -i correct=0 wrong=0 timeout_count=0
    local start_time
    start_time=$(date +%s)

    local cleanup_called=false
    cleanup_quiz() {
        $cleanup_called && return
        cleanup_called=true
        show_cursor
        echo ""
    }
    trap cleanup_quiz EXIT INT TERM
    hide_cursor

    for (( q=0; q<total; q++ )); do
        IFS='|' read -r question opt_a opt_b opt_c opt_d answer explanation <<< "${all_questions[$q]}"

        clear_screen
        print_center "💻  IT知識クイズ  💻" 1 "$C_CYAN"
        move_cursor 2 2
        printf "  問題 %d/%d  |  カテゴリ: %s  |  正解: ${C_GREEN}%d${C_RESET}  誤答: ${C_RED}%d${C_RESET}" \
            "$(( q + 1 ))" "$total" "$category" "$correct" "$wrong"
        draw_separator 3

        # 問題表示
        move_cursor 5 2
        printf "  ${C_BOLD}Q%d. %s${C_RESET}\n" "$(( q + 1 ))" "$question"

        echo ""
        move_cursor 7 2
        printf "  ${C_CYAN}[A]${C_RESET} %s\n" "${opt_a#A:}"
        move_cursor 8 2
        printf "  ${C_CYAN}[B]${C_RESET} %s\n" "${opt_b#B:}"
        move_cursor 9 2
        printf "  ${C_CYAN}[C]${C_RESET} %s\n" "${opt_c#C:}"
        move_cursor 10 2
        printf "  ${C_CYAN}[D]${C_RESET} %s\n" "${opt_d#D:}"

        move_cursor 12 2
        printf "  ${C_DIM}制限時間: %d秒  [A/B/C/D]=回答  [q]=終了${C_RESET}" "$time_limit"

        # タイマー表示
        local q_start
        q_start=$(date +%s)
        local user_ans=""

        while true; do
            local now
            now=$(date +%s)
            local elapsed=$(( now - q_start ))
            local remaining=$(( time_limit - elapsed ))

            (( remaining <= 0 )) && { user_ans="TIMEOUT"; break; }

            local timer_color="$C_GREEN"
            (( remaining <= 5 )) && timer_color="${C_RED}${C_BOLD}"
            (( remaining <= 10 && remaining > 5 )) && timer_color="$C_YELLOW"

            move_cursor 13 2
            printf "  残り時間: ${timer_color}%2d秒${C_RESET}  " "$remaining"

            local key=""
            IFS= read -r -s -n1 -t 1 key 2>/dev/null || true
            case "${key:-}" in
                a|A) user_ans="A"; break ;;
                b|B) user_ans="B"; break ;;
                c|C) user_ans="C"; break ;;
                d|D) user_ans="D"; break ;;
                q|Q) break 2 ;;
            esac
        done

        # 結果表示
        move_cursor 15 2
        if [[ "$user_ans" == "TIMEOUT" ]]; then
            printf "  ${C_YELLOW}時間切れ！${C_RESET} 正解は ${C_GREEN}${answer}${C_RESET}\n"
            (( timeout_count++ )) || true
            (( wrong++ )) || true
        elif [[ "$user_ans" == "$answer" ]]; then
            printf "  ${C_GREEN}${C_BOLD}正解！${C_RESET}\n"
            (( correct++ )) || true
        else
            printf "  ${C_RED}不正解... ${C_RESET}正解は ${C_GREEN}${answer}${C_RESET}\n"
            (( wrong++ )) || true
        fi

        move_cursor 17 2
        printf "  ${C_DIM}解説: %s${C_RESET}\n" "$explanation"

        move_cursor 19 2
        printf "  ${C_DIM}Enterで次へ...${C_RESET}"
        IFS= read -r -s -n1 key || true
        [[ "${key:-}" == "q" ]] && break
    done

    local end_time
    end_time=$(date +%s)
    local total_time=$(( end_time - start_time ))
    local accuracy=0
    (( correct + wrong > 0 )) && accuracy=$(( correct * 100 / (correct + wrong) ))

    clear_screen
    print_center "クイズ終了！" 2 "$C_CYAN"
    draw_separator 3
    echo ""
    move_cursor 5 2
    printf "  正解数: ${C_GREEN}${C_BOLD}%d${C_RESET} / %d\n" "$correct" "$total"
    printf "  正答率: ${C_CYAN}${C_BOLD}%d%%${C_RESET}\n" "$accuracy"
    printf "  所要時間: %d秒\n" "$total_time"
    printf "  タイムアウト: ${C_YELLOW}%d問${C_RESET}\n" "$timeout_count"

    local rank
    if (( accuracy >= 90 )); then rank="${C_YELLOW}S (ITマスター)${C_RESET}"
    elif (( accuracy >= 70 )); then rank="${C_GREEN}A (上級者)${C_RESET}"
    elif (( accuracy >= 50 )); then rank="${C_CYAN}B (中級者)${C_RESET}"
    else rank="${C_RED}C (要勉強)${C_RESET}"
    fi

    echo ""
    move_cursor 11 2
    printf "  ランク: %b\n" "$rank"
    echo ""
    move_cursor 13 2
    printf "  ${C_DIM}Enterで終了...${C_RESET}"
    IFS= read -r -s -n1 || true
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--category)
                [[ $# -lt 2 ]] && error_exit "-c には値が必要です"
                category="$2"
                case "$category" in
                    linux|network|security|infra|all) ;;
                    *) error_exit "無効なカテゴリ: $category" ;;
                esac
                shift 2
                ;;
            -n|--count)  [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; question_count="$2"; shift 2 ;;
            -t|--time)   [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; time_limit="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    play_quiz
}

main "$@"
