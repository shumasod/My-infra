<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>コーディングパズル チャレンジ</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2em;
            margin-bottom: 10px;
        }
        
        .progress-bar {
            background: rgba(255,255,255,0.3);
            height: 10px;
            border-radius: 5px;
            margin-top: 20px;
            overflow: hidden;
        }
        
        .progress-fill {
            background: #4ade80;
            height: 100%;
            width: 0%;
            transition: width 0.5s ease;
        }
        
        .level-selector {
            display: flex;
            justify-content: center;
            gap: 10px;
            padding: 20px;
            background: #f8fafc;
            flex-wrap: wrap;
        }
        
        .level-btn {
            padding: 10px 20px;
            border: 2px solid #667eea;
            background: white;
            color: #667eea;
            border-radius: 10px;
            cursor: pointer;
            font-weight: bold;
            transition: all 0.3s;
        }
        
        .level-btn:hover {
            background: #667eea;
            color: white;
            transform: translateY(-2px);
        }
        
        .level-btn.active {
            background: #667eea;
            color: white;
        }
        
        .level-btn.completed {
            background: #4ade80;
            border-color: #4ade80;
            color: white;
        }
        
        .level-btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        
        .content {
            padding: 30px;
        }
        
        .puzzle {
            display: none;
        }
        
        .puzzle.active {
            display: block;
            animation: fadeIn 0.5s;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        .puzzle-title {
            color: #667eea;
            font-size: 1.5em;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .difficulty {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.6em;
            font-weight: bold;
        }
        
        .difficulty.easy { background: #4ade80; color: white; }
        .difficulty.medium { background: #fbbf24; color: white; }
        .difficulty.hard { background: #f87171; color: white; }
        .difficulty.expert { background: #8b5cf6; color: white; }
        
        .puzzle-description {
            background: #f1f5f9;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            line-height: 1.8;
        }
        
        .code-block {
            background: #1e293b;
            color: #e2e8f0;
            padding: 20px;
            border-radius: 10px;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            overflow-x: auto;
            margin: 15px 0;
            line-height: 1.6;
        }
        
        .code-block .comment { color: #6ee7b7; }
        .code-block .keyword { color: #fb923c; }
        .code-block .string { color: #a5f3fc; }
        .code-block .function { color: #fde047; }
        
        .answer-area {
            margin: 20px 0;
        }
        
        textarea {
            width: 100%;
            min-height: 150px;
            padding: 15px;
            border: 2px solid #e2e8f0;
            border-radius: 10px;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            resize: vertical;
            transition: border-color 0.3s;
        }
        
        textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .button-group {
            display: flex;
            gap: 10px;
            margin-top: 20px;
            flex-wrap: wrap;
        }
        
        button {
            padding: 12px 24px;
            border: none;
            border-radius: 10px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s;
            font-size: 14px;
        }
        
        .submit-btn {
            background: #667eea;
            color: white;
        }
        
        .submit-btn:hover {
            background: #5568d3;
            transform: translateY(-2px);
        }
        
        .hint-btn {
            background: #fbbf24;
            color: white;
        }
        
        .hint-btn:hover {
            background: #f59e0b;
        }
        
        .reset-btn {
            background: #64748b;
            color: white;
        }
        
        .reset-btn:hover {
            background: #475569;
        }
        
        .feedback {
            margin-top: 20px;
            padding: 20px;
            border-radius: 10px;
            display: none;
            animation: slideIn 0.5s;
        }
        
        @keyframes slideIn {
            from { opacity: 0; transform: translateX(-20px); }
            to { opacity: 1; transform: translateX(0); }
        }
        
        .feedback.show {
            display: block;
        }
        
        .feedback.success {
            background: #d1fae5;
            border: 2px solid #4ade80;
            color: #065f46;
        }
        
        .feedback.error {
            background: #fee2e2;
            border: 2px solid #f87171;
            color: #991b1b;
        }
        
        .feedback.hint {
            background: #fef3c7;
            border: 2px solid #fbbf24;
            color: #92400e;
        }
        
        .hint-content {
            display: none;
            margin-top: 10px;
            padding-top: 10px;
            border-top: 1px solid currentColor;
        }
        
        .stats {
            display: flex;
            justify-content: space-around;
            padding: 20px;
            background: #f8fafc;
            border-radius: 10px;
            margin-top: 20px;
            flex-wrap: wrap;
            gap: 15px;
        }
        
        .stat-item {
            text-align: center;
        }
        
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            color: #64748b;
            font-size: 0.9em;
            margin-top: 5px;
        }
        
        .celebration {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            display: none;
            z-index: 1000;
            text-align: center;
            max-width: 400px;
        }
        
        .celebration.show {
            display: block;
            animation: bounceIn 0.5s;
        }
        
        @keyframes bounceIn {
            0% { transform: translate(-50%, -50%) scale(0.3); }
            50% { transform: translate(-50%, -50%) scale(1.05); }
            100% { transform: translate(-50%, -50%) scale(1); }
        }
        
        .celebration h2 {
            color: #667eea;
            font-size: 2em;
            margin-bottom: 20px;
        }
        
        .overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            display: none;
            z-index: 999;
        }
        
        .overlay.show {
            display: block;
        }
    </style>
</head>
<body>
    <div class="overlay" id="overlay"></div>
    <div class="celebration" id="celebration">
        <h2>🎉 おめでとうございます!</h2>
        <p id="celebrationMessage"></p>
        <button class="submit-btn" onclick="closeCelebration()">次のパズルへ</button>
    </div>
    
    <div class="container">
        <div class="header">
            <h1>🧩 コーディングパズル チャレンジ</h1>
            <p>シェルスクリプトを改善しながら学ぼう!</p>
            <div class="progress-bar">
                <div class="progress-fill" id="progressBar"></div>
            </div>
        </div>
        
        <div class="level-selector" id="levelSelector"></div>
        
        <div class="content">
            <div id="puzzleContainer"></div>
            
            <div class="stats">
                <div class="stat-item">
                    <div class="stat-value" id="solvedCount">0</div>
                    <div class="stat-label">解決済み</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value" id="hintsUsed">0</div>
                    <div class="stat-label">ヒント使用</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value" id="attempts">0</div>
                    <div class="stat-label">挑戦回数</div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const puzzles = [
            {
                id: 1,
                title: "Level 1: エラーハンドリングを追加",
                difficulty: "easy",
                description: `元のスクリプトには基本的なエラーハンドリングがありません。<br><br>
                <strong>課題:</strong> generate_report関数でエラーが発生した場合に、エラーメッセージを表示して処理を終了するようにしてください。<br><br>
                <strong>ヒント:</strong> 関数の戻り値やコマンドの終了ステータス($?)を確認しましょう。`,
                code: `generate_report() {
    echo "日次レポート: \\${DATE}" > \\${REPORT_FILE}
    # ここでエラーチェックを追加
    echo "レポート終了" >> \\${REPORT_FILE}
}`,
                hints: [
                    "コマンドの実行結果は $? で確認できます",
                    "if [ $? -ne 0 ]; then を使ってエラーチェックを行いましょう",
                    "エラー時は stderr に出力して exit 1 で終了します"
                ],
                solution: `generate_report() {
    echo "日次レポート: \\${DATE}" > \\${REPORT_FILE}
    if [ $? -ne 0 ]; then
        echo "エラー: レポートファイルの作成に失敗しました" >&2
        exit 1
    fi
    echo "レポート終了" >> \\${REPORT_FILE}
}`,
                checkAnswer: function(answer) {
                    const checks = [
                        { pattern: /\$\?/, message: "終了ステータス($?)のチェックが含まれています" },
                        { pattern: /if.*\[.*\].*then/i, message: "条件分岐が含まれています" },
                        { pattern: />&2|stderr/i, message: "標準エラー出力への出力が含まれています" },
                        { pattern: /exit\s+1/, message: "エラー時の終了処理が含まれています" }
                    ];
                    let score = 0;
                    let feedback = [];
                    
                    checks.forEach(check => {
                        if (check.pattern.test(answer)) {
                            score++;
                            feedback.push("✓ " + check.message);
                        }
                    });
                    
                    return {
                        passed: score >= 3,
                        score: score,
                        feedback: feedback.join("<br>"),
                        message: score >= 3 ? "素晴らしい!適切なエラーハンドリングが実装されています!" : "もう少しです!ヒントを参考にしてみてください。"
                    };
                }
            },
            {
                id: 2,
                title: "Level 2: 関数の戻り値を活用",
                difficulty: "easy",
                description: `関数の成功/失敗を戻り値で伝えることで、より柔軟なエラーハンドリングができます。<br><br>
                <strong>課題:</strong> generate_report関数が成功時に0、失敗時に1を返すように修正し、main関数でその戻り値をチェックしてください。<br><br>
                <strong>ヒント:</strong> return文を使って関数から値を返せます。`,
                code: `generate_report() {
    # 関数内で処理を実行
    # 戻り値を返すように修正
}

main() {
    generate_report
    # ここで戻り値をチェック
}`,
                hints: [
                    "関数の最後に return 0 または return 1 を追加します",
                    "関数呼び出し後、すぐに if [ $? -eq 0 ]; then でチェックできます",
                    "または、if generate_report; then の形式も使えます"
                ],
                solution: `generate_report() {
    echo "日次レポート: \\${DATE}" > \\${REPORT_FILE} || return 1
    echo "-------------------" >> \\${REPORT_FILE} || return 1
    uptime >> \\${REPORT_FILE} || return 1
    return 0
}

main() {
    if ! generate_report; then
        echo "エラー: レポート生成に失敗しました" >&2
        exit 1
    fi
    send_email
}`,
                checkAnswer: function(answer) {
                    const checks = [
                        { pattern: /return\s+[01]/, message: "return文で戻り値を返しています" },
                        { pattern: /if\s+(!|.*generate_report)/i, message: "関数の戻り値をチェックしています" },
                        { pattern: /\|\|\s*return/i, message: "コマンド失敗時の早期リターンを実装しています" }
                    ];
                    let score = 0;
                    let feedback = [];
                    
                    checks.forEach(check => {
                        if (check.pattern.test(answer)) {
                            score++;
                            feedback.push("✓ " + check.message);
                        }
                    });
                    
                    return {
                        passed: score >= 2,
                        score: score,
                        feedback: feedback.join("<br>"),
                        message: score >= 2 ? "完璧です!関数の戻り値を適切に活用できています!" : "returnとifの組み合わせを確認してみましょう。"
                    };
                }
            },
            {
                id: 3,
                title: "Level 3: ログ機能を追加",
                difficulty: "medium",
                description: `デバッグやトラブルシューティングのために、実行ログを記録する機能を追加しましょう。<br><br>
                <strong>課題:</strong> log_message関数を作成し、各処理の開始・終了・エラーをログファイルに記録してください。ログには日時とログレベル(INFO/ERROR)を含めましょう。<br><br>
                <strong>ヒント:</strong> date コマンドで詳細な日時を取得できます。`,
                code: `LOG_FILE="script.log"

log_message() {
    # ログレベルとメッセージを受け取る
    # 日時付きでログファイルに記録
}

main() {
    # ここでlog_messageを使って処理を記録
    generate_report
    send_email
}`,
                hints: [
                    "log_message関数は2つの引数(ログレベルとメッセージ)を受け取ります",
                    "date '+%Y-%m-%d %H:%M:%S' で詳細な日時を取得できます",
                    "ログ形式: [日時] [レベル] メッセージ のようにします"
                ],
                solution: `LOG_FILE="/var/log/daily_report.log"

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[\\${timestamp}] [\\${level}] \\${message}" >> "\\${LOG_FILE}"
}

main() {
    log_message "INFO" "スクリプト開始"
    
    if generate_report; then
        log_message "INFO" "レポート生成完了"
    else
        log_message "ERROR" "レポート生成失敗"
        exit 1
    fi
    
    if send_email; then
        log_message "INFO" "メール送信完了"
    else
        log_message "ERROR" "メール送信失敗"
        exit 1
    fi
    
    log_message "INFO" "スクリプト正常終了"
}`,
                checkAnswer: function(answer) {
                    const checks = [
                        { pattern: /log_message.*{/, message: "log_message関数が定義されています" },
                        { pattern: /date.*['"]\+.*%.*%.*%/, message: "dateコマンドで日時を取得しています" },
                        { pattern: /\[\$\{?timestamp/, message: "ログに日時を含めています" },
                        { pattern: /\[\$\{?level/, message: "ログレベルを含めています" },
                        { pattern: /log_message.*INFO|log_message.*ERROR/i, message: "実際にログ記録を使用しています" }
                    ];
                    let score = 0;
                    let feedback = [];
                    
                    checks.forEach(check => {
                        if (check.pattern.test(answer)) {
                            score++;
                            feedback.push("✓ " + check.message);
                        }
                    });
                    
                    return {
                        passed: score >= 4,
                        score: score,
                        feedback: feedback.join("<br>"),
                        message: score >= 4 ? "素晴らしい!実用的なログ機能が実装できました!" : "ログの形式と使用方法を確認してみましょう。"
                    };
                }
            },
            {
                id: 4,
                title: "Level 4: 設定ファイルの読み込み",
                difficulty: "medium",
                description: `ハードコーディングされた値を設定ファイルから読み込めるようにして、柔軟性を高めましょう。<br><br>
                <strong>課題:</strong> config.conf ファイルから設定を読み込む load_config 関数を作成してください。設定ファイルがない場合はデフォルト値を使用するようにしましょう。<br><br>
                <strong>ヒント:</strong> sourceコマンドやreadコマンドが使えます。`,
                code: `CONFIG_FILE="config.conf"

load_config() {
    # 設定ファイルを読み込む
    # ファイルがない場合はデフォルト値を設定
}

main() {
    load_config
    # 以降の処理
}`,
                hints: [
                    "[ -f \"\${CONFIG_FILE}\" ] でファイルの存在確認ができます",
                    "source コマンドでシェルスクリプトの変数を読み込めます",
                    "設定ファイルには KEY=value の形式で記述します"
                ],
                solution: `CONFIG_FILE="\\${HOME}/.daily_report.conf"

# デフォルト設定
RECIPIENT="\\${RECIPIENT:-admin@example.com}"
REPORT_DIR="\\${REPORT_DIR:-/tmp/reports}"
LOG_DIR="\\${LOG_DIR:-/var/log}"

load_config() {
    if [ -f "\\${CONFIG_FILE}" ]; then
        log_message "INFO" "設定ファイル読み込み: \\${CONFIG_FILE}"
        source "\\${CONFIG_FILE}"
        
        if [ $? -ne 0 ]; then
            log_message "ERROR" "設定ファイルの読み込みに失敗"
            return 1
        fi
    else
        log_message "WARN" "設定ファイルなし。デフォルト値を使用"
    fi
    
    # 必須ディレクトリの作成
    mkdir -p "\\${REPORT_DIR}" "\\${LOG_DIR}"
    
    return 0
}

main() {
    if ! load_config; then
        echo "設定の読み込みに失敗しました" >&2
        exit 1
    fi
    
    # 以降の処理
}`,
                checkAnswer: function(answer) {
                    const checks = [
                        { pattern: /\[\s+-f.*CONFIG_FILE/i, message: "ファイルの存在確認をしています" },
                        { pattern: /source|\..*CONFIG_FILE/i, message: "設定ファイルを読み込んでいます" },
                        { pattern: /:=|-|デフォルト/i, message: "デフォルト値の設定があります" },
                        { pattern: /mkdir.*-p/i, message: "必要なディレクトリを作成しています" }
                    ];
                    let score = 0;
                    let feedback = [];
                    
                    checks.forEach(check => {
                        if (check.pattern.test(answer)) {
                            score++;
                            feedback.push("✓ " + check.message);
                        }
                    });
                    
                    return {
                        passed: score >= 3,
                        score: score,
                        feedback: feedback.join("<br>"),
                        message: score >= 3 ? "完璧!柔軟な設定管理ができるようになりました!" : "ファイルチェックとsourceの使い方を確認しましょう。"
                    };
                }
            },
            {
                id: 5,
                title: "Level 5: リトライロジックの実装",
                difficulty: "hard",
                description: `ネットワークエラーなど一時的な失敗に対応するため、リトライ機能を実装しましょう。<br><br>
                <strong>課題:</strong> コマンドを指定回数リトライする retry 関数を作成してください。指数バックオフ(待ち時間を徐々に増やす)を実装しましょう。<br><br>
                <strong>ヒント:</strong> sleep コマンドで待機でき、$((算術式))で計算できます。`,
                code: `retry() {
    local max_attempts=$1
    shift
    local command="$@"
    
    # リトライロジックを実装
}

# 使用例
retry 3 send_email`,
                hints: [
                    "forループで指定回数繰り返します: for i in $(seq 1 \$max_attempts)",
                    "指数バックオフ: wait_time=$((2 ** (i-1))) のように計算します",
                    "eval コマンドで変数に格納されたコマンドを実行できます"
                ],
                solution: `retry() {
    local max_attempts=$1
    shift
    local command="$@"
    local attempt=1
    
    while [ \\${attempt} -le \\${max_attempts} ]; do
        log_message "INFO" "実行試行 \\${attempt}/\\${max_attempts}: \\${command}"
        
        if eval "\\${command}"; then
            log_message "INFO" "成功"
            return 0
        fi
        
        if [ \\${attempt} -lt \\${max_attempts} ]; then
            local wait_time=$((2 ** (attempt - 1)))
            log_message "WARN" "失敗。\\${wait_time}秒後にリトライ..."
            sleep \\${wait_time}
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_message "ERROR" "最大試行回数に達しました: \\${command}"
    return 1
}

send_email() {
    # メール送信処理
    echo "\\${BODY}" | mail -s "\\${SUBJECT}" -a \\${REPORT_FILE} \\${RECIPIENT}
}

main() {
    load_config
    
    if ! generate_report; then
        exit 1
    fi
    
    # 3回までリトライ
    if ! retry 3 send_email; then
        log_message "ERROR" "メール送信に失敗しました"
        exit 1
    fi
}`,
                checkAnswer: function(answer) {
                    const checks = [
                        { pattern: /while.*\[.*attempt.*max_attempts|for.*seq/i, message: "ループでリトライを実装しています" },
                        { pattern: /eval.*command/i, message: "動的にコマンドを実行しています" },
                        { pattern: /2\s*\*\*.*attempt|attempt.*\*\*\s*2/i, message: "指数バックオフを実装しています" },
                        { pattern: /sleep/i, message: "待機処理があります" },
                        { pattern: /return\s+0.*return\s+1/s, message: "成功・失敗の戻り値が適切です" }
                    ];
                    let score = 0;
                    let feedback = [];
                    
                    checks.forEach(check => {
                        if (check.pattern.test(answer)) {
                            score++;
                            feedback.push("✓ " + check.message);
                        }
                    });
                    
                    return {
                        passed: score >= 4,
                        score: score,
                        feedback: feedback.join("<br>"),
                        message: score >= 4 ? "すごい!本格的なリトライ機能が完成しました!" : "ループ、指数計算、sleepの組み合わせを確認しましょう。"
                    };
                }
            },
            {
                id: 6,
                title: "Level 6: 並列実行と排他制御",
                difficulty: "hard",
                description: `複数のレポート処理を並列実行しつつ、同時実行を防ぐロック機構を実装しましょう。<br><br>
                <strong>課題:</strong> ロックファイルを使って同時実行を防ぎ、バックグラウンドプロセスで並列処理を実装してください。<br><br>
                <strong>ヒント:</strong> flock や独自のロック機構、& と wait を組み合わせます。`,
                code: `LOCK_FILE="/var/run/daily_report.lock"

acquire_lock() {
    # ロックを取得
}

release_lock() {
    # ロックを解放
}

main() {
    acquire_lock
    # 並列処理の実装
    release_lock
}`,
                hints: [
                    "mkdir を使った原子的なロック: mkdir \"\${LOCK_FILE}\" 2>/dev/null",
                    "バックグラウンド実行: command & で実行し、wait で全プロセスの完了を待ちます",
                    "trap コマンドでシグナルを捕捉し、終了時に確実にロックを解放します"
                ],
                solution: `LOCK_FILE="/var/run/daily_report.lock"
PID_FILE="\\${LOCK_FILE}/pid"

acquire_lock() {
    local max_wait=30
    local waited=0
    
    while ! mkdir "\\${LOCK_FILE}" 2>/dev/null; do
        if [ \\${waited} -ge \\${max_wait} ]; then
            log_message "ERROR" "ロック取得タイムアウト"
            return 1
        fi
        
        log_message "INFO" "ロック待機中..."
        sleep 1
        waited=$((waited + 1))
    done
    
    echo $$ > "\\${PID_FILE}"
    log_message "INFO" "ロック取得 (PID: $$)"
    
    # 終了時に確実にロックを解放
    trap release_lock EXIT INT TERM
    
    return 0
}

release_lock() {
    if [ -d "\\${LOCK_FILE}" ]; then
        rm -rf "\\${LOCK_FILE}"
        log_message "INFO" "ロック解放"
    fi
}

generate_system_report() {
    log_message "INFO" "システムレポート生成開始"
    uptime >> "\\${REPORT_FILE}"
    df -h >> "\\${REPORT_FILE}"
    return 0
}

generate_memory_report() {
    log_message "INFO" "メモリレポート生成開始"
    free -m >> "\\${REPORT_FILE}"
    return 0
}

main() {
    if ! acquire_lock; then
        exit 1
    fi
    
    load_config
    
    # 並列処理で複数のレポートを生成
    generate_system_report &
    local pid1=$!
    
    generate_memory_report &
    local pid2=$!
    
    # 全プロセスの完了を待つ
    wait \\${pid1} && wait \\${pid2}
    
    if [ $? -eq 0 ]; then
        retry 3 send_email
    fi
}`,
                checkAnswer: function(answer) {
                    const checks = [
                        { pattern: /mkdir.*LOCK_FILE.*2>\/dev\/null/i, message: "原子的なロック機構を実装しています" },
                        { pattern: /trap.*release_lock.*EXIT/i, message: "trapで確実なロック解放を実装しています" },
                        { pattern: /&\s*$/m, message: "バックグラウンド実行を使っています" },
                        { pattern: /wait/i, message: "waitで並列プロセスの完了を待っています" },
                        { pattern: /\$!/i, message: "プロセスIDを取得しています" }
                    ];
                    let score = 0;
                    let feedback = [];
                    
                    checks.forEach(check => {
                        if (check.pattern.test(answer)) {
                            score++;
                            feedback.push("✓ " + check.message);
                        }
                    });
                    
                    return {
                        passed: score >= 4,
                        score: score,
                        feedback: feedback.join("<br>"),
                        message: score >= 4 ? "完璧!プロダクションレベルの排他制御と並列処理です!" : "ロック、trap、バックグラウンド実行の組み合わせを確認しましょう。"
                    };
                }
            },
            {
                id: 7,
                title: "Level 7: 総合演習 - プロダクション対応",
                difficulty: "expert",
                description: `これまで学んだすべてを統合して、プロダクション環境で使える堅牢なスクリプトを完成させましょう。<br><br>
                <strong>課題:</strong> 以下の要件を満たすスクリプトを作成してください:<br>
                ✓ コマンドライン引数の処理(--help, --dry-run, --config)<br>
                ✓ dry-runモードの実装<br>
                ✓ シグナルハンドリング(SIGINT, SIGTERM)<br>
                ✓ 詳細なステータス表示<br>
                ✓ メトリクス収集(実行時間、成功/失敗数)<br><br>
                <strong>難易度:</strong> これまでの知識を総動員する必要があります!`,
                code: `#!/bin/bash
# 総合演習: すべての機能を統合
# ここに完成形のスクリプトを作成しましょう`,
                hints: [
                    "getopts でコマンドライン引数を処理できます: while getopts 'hd:' opt; do",
                    "DRY_RUN フラグを用意し、実際のコマンド実行前にチェックします",
                    "trap で複数のシグナルを処理: trap cleanup SIGINT SIGTERM",
                    "time コマンドや date の差分で実行時間を計測できます"
                ],
                solution: `#!/bin/bash
set -euo pipefail

# グローバル変数
SCRIPT_NAME=$(basename "$0")
VERSION="1.0.0"
DRY_RUN=false
CONFIG_FILE="\\${HOME}/.daily_report.conf"
LOCK_FILE="/var/run/\\${SCRIPT_NAME}.lock"
LOG_FILE="/var/log/\\${SCRIPT_NAME}.log"

# メトリクス
START_TIME=$(date +%s)
SUCCESS_COUNT=0
FAILURE_COUNT=0

# デフォルト設定
RECIPIENT="\\${RECIPIENT:-admin@example.com}"
REPORT_DIR="\\${REPORT_DIR:-/tmp/reports}"
MAX_RETRIES=3

usage() {
    cat << EOF
使用方法: \\${SCRIPT_NAME} [オプション]

オプション:
    -h, --help          このヘルプを表示
    -c, --config FILE   設定ファイルを指定 (デフォルト: \\${CONFIG_FILE})
    -d, --dry-run       実際には実行せず、動作を確認
    -v, --verbose       詳細な出力
    --version           バージョン情報を表示

例:
    \\${SCRIPT_NAME} --dry-run
    \\${SCRIPT_NAME} --config /etc/report.conf
EOF
    exit 0
}

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[\\${timestamp}] [\\${level}] \\${message}" | tee -a "\\${LOG_FILE}"
}

cleanup() {
    log_message "INFO" "クリーンアップ処理開始"
    release_lock
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    log_message "INFO" "実行完了: 成功=\\${SUCCESS_COUNT}, 失敗=\\${FAILURE_COUNT}, 実行時間=\\${duration}秒"
    exit 0
}

handle_error() {
    log_message "ERROR" "エラーが発生しました: $1"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    cleanup
    exit 1
}

# シグナルハンドリング
trap cleanup EXIT
trap 'handle_error "SIGINT受信"' INT
trap 'handle_error "SIGTERM受信"' TERM

acquire_lock() {
    if ! mkdir "\\${LOCK_FILE}" 2>/dev/null; then
        handle_error "既に実行中です (ロックファイル: \\${LOCK_FILE})"
    fi
    echo $$ > "\\${LOCK_FILE}/pid"
}

release_lock() {
    [ -d "\\${LOCK_FILE}" ] && rm -rf "\\${LOCK_FILE}"
}

execute_command() {
    local cmd=$1
    
    if [ "\\${DRY_RUN}" = true ]; then
        log_message "DRY-RUN" "実行予定: \\${cmd}"
        return 0
    fi
    
    eval "\\${cmd}"
}

# コマンドライン引数の処理
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage ;;
        -c|--config) CONFIG_FILE="$2"; shift 2 ;;
        -d|--dry-run) DRY_RUN=true; shift ;;
        --version) echo "\\${SCRIPT_NAME} v\\${VERSION}"; exit 0 ;;
        *) echo "不明なオプション: $1"; usage ;;
    esac
done

main() {
    log_message "INFO" "スクリプト開始 (DRY_RUN=\\${DRY_RUN})"
    
    acquire_lock
    
    if ! load_config; then
        handle_error "設定読み込み失敗"
    fi
    
    if ! generate_report; then
        handle_error "レポート生成失敗"
    fi
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    
    if ! retry \\${MAX_RETRIES} send_email; then
        handle_error "メール送信失敗"
    fi
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    
    log_message "INFO" "すべての処理が正常に完了しました"
}

main`,
                checkAnswer: function(answer) {
                    const checks = [
                        { pattern: /getopts|while.*\[\[.*\$#.*-gt.*0|case.*\$1/i, message: "コマンドライン引数を処理しています" },
                        { pattern: /DRY_RUN|dry.run/i, message: "dry-runモードを実装しています" },
                        { pattern: /trap.*cleanup.*EXIT/i, message: "EXITトラップでクリーンアップを実装しています" },
                        { pattern: /trap.*(INT|TERM)/i, message: "シグナルハンドリングを実装しています" },
                        { pattern: /START_TIME|END_TIME|duration/i, message: "実行時間を計測しています" },
                        { pattern: /SUCCESS_COUNT|FAILURE_COUNT/i, message: "メトリクスを収集しています" },
                        { pattern: /usage\(\)|--help/i, message: "ヘルプ機能があります" },
                        { pattern: /set\s+-[euo]+/i, message: "安全なシェルオプションを設定しています" }
                    ];
                    let score = 0;
                    let feedback = [];
                    
                    checks.forEach(check => {
                        if (check.pattern.test(answer)) {
                            score++;
                            feedback.push("✓ " + check.message);
                        }
                    });
                    
                    return {
                        passed: score >= 6,
                        score: score,
                        feedback: feedback.join("<br>"),
                        message: score >= 6 ? 
                            "🎉 完璧です!プロダクション環境で使える本格的なスクリプトが完成しました!" : 
                            "あと少しです!コマンドライン引数、トラップ、メトリクスの実装を確認しましょう。"
                    };
                }
            }
        ];

        let currentLevel = 0;
        let stats = {
            solved: 0,
            hints: 0,
            attempts: 0
        };

        function init() {
            renderLevelSelector();
            loadPuzzle(0);
            updateStats();
        }

        function renderLevelSelector() {
            const selector = document.getElementById('levelSelector');
            puzzles.forEach((puzzle, index) => {
                const btn = document.createElement('button');
                btn.className = 'level-btn';
                btn.textContent = `Level ${puzzle.id}`;
                btn.onclick = () => loadPuzzle(index);
                if (index > 0) btn.disabled = true;
                btn.id = `level-btn-${index}`;
                selector.appendChild(btn);
            });
        }

        function loadPuzzle(index) {
            currentLevel = index;
            const puzzle = puzzles[index];
            
            // アクティブなボタンを更新
            document.querySelectorAll('.level-btn').forEach((btn, i) => {
                btn.classList.toggle('active', i === index);
            });
            
            const container = document.getElementById('puzzleContainer');
            container.innerHTML = `
                <div class="puzzle active">
                    <h2 class="puzzle-title">
                        ${puzzle.title}
                        <span class="difficulty ${puzzle.difficulty}">
                            ${puzzle.difficulty === 'easy' ? '初級' : 
                              puzzle.difficulty === 'medium' ? '中級' : 
                              puzzle.difficulty === 'hard' ? '上級' : 'エキスパート'}
                        </span>
                    </h2>
                    <div class="puzzle-description">${puzzle.description}</div>
                    <div class="code-block">${escapeHtml(puzzle.code)}</div>
                    <div class="answer-area">
                        <label style="display: block; margin-bottom: 10px; font-weight: bold; color: #475569;">
                            💡 あなたの解答:
                        </label>
                        <textarea id="answer" placeholder="ここにコードを記述してください..."></textarea>
                    </div>
                    <div class="button-group">
                        <button class="submit-btn" onclick="checkAnswer()">✓ 解答を確認</button>
                        <button class="hint-btn" onclick="showHint()">💡 ヒント</button>
                        <button class="reset-btn" onclick="resetAnswer()">↺ リセット</button>
                    </div>
                    <div class="feedback" id="feedback"></div>
                </div>
            `;
            
            updateProgress();
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function checkAnswer() {
            const answer = document.getElementById('answer').value.trim();
            const feedback = document.getElementById('feedback');
            const puzzle = puzzles[currentLevel];
            
            stats.attempts++;
            updateStats();
            
            if (!answer) {
                feedback.className = 'feedback error show';
                feedback.innerHTML = '<strong>❌ エラー</strong><br>解答を入力してください。';
                return;
            }
            
            const result = puzzle.checkAnswer(answer);
            
            if (result.passed) {
                feedback.className = 'feedback success show';
                feedback.innerHTML = `
                    <strong>✅ 正解!</strong><br>
                    ${result.feedback}<br><br>
                    ${result.message}
                `;
                
                stats.solved++;
                updateStats();
                
                // レベルを完了済みにマーク
                const btn = document.getElementById(`level-btn-${currentLevel}`);
                btn.classList.add('completed');
                
                // 次のレベルをアンロック
                if (currentLevel < puzzles.length - 1) {
                    const nextBtn = document.getElementById(`level-btn-${currentLevel + 1}`);
                    nextBtn.disabled = false;
                    
                    setTimeout(() => {
                        showCelebration();
                    }, 500);
                } else {
                    // 全問正解
                    setTimeout(() => {
                        showFinalCelebration();
                    }, 500);
                }
            } else {
                feedback.className = 'feedback error show';
                feedback.innerHTML = `
                    <strong>❌ もう一度挑戦!</strong><br>
                    ${result.feedback ? result.feedback + '<br><br>' : ''}
                    ${result.message}
                `;
            }
        }

        let hintLevel = 0;

        function showHint() {
            const puzzle = puzzles[currentLevel];
            const feedback = document.getElementById('feedback');
            
            if (hintLevel >= puzzle.hints.length) {
                feedback.className = 'feedback hint show';
                feedback.innerHTML = '<strong>💡 すべてのヒント</strong><br>' + 
                    puzzle.hints.map((h, i) => `${i + 1}. ${h}`).join('<br>');
                return;
            }
            
            stats.hints++;
            updateStats();
            
            feedback.className = 'feedback hint show';
            feedback.innerHTML = `<strong>💡 ヒント ${hintLevel + 1}</strong><br>${puzzle.hints[hintLevel]}`;
            hintLevel++;
        }

        function resetAnswer() {
            document.getElementById('answer').value = '';
            document.getElementById('feedback').className = 'feedback';
            hintLevel = 0;
        }

        function showCelebration() {
            const overlay = document.getElementById('overlay');
            const celebration = document.getElementById('celebration');
            const message = document.getElementById('celebrationMessage');
            
            message.textContent = `Level ${puzzles[currentLevel].id} クリア!次のレベルに挑戦しましょう!`;
            
            overlay.classList.add('show');
            celebration.classList.add('show');
        }

        function showFinalCelebration() {
            const overlay = document.getElementById('overlay');
            const celebration = document.getElementById('celebration');
            const message = document.getElementById('celebrationMessage');
            
            message.innerHTML = `
                全${puzzles.length}レベルクリア!おめでとうございます!🎊<br><br>
                <small>プロダクションレベルのシェルスクリプトが書けるようになりました!</small>
            `;
            
            celebration.querySelector('button').textContent = '完了';
            celebration.querySelector('button').onclick = closeCelebration;
            
            overlay.classList.add('show');
            celebration.classList.add('show');
        }

        function closeCelebration() {
            const overlay = document.getElementById('overlay');
            const celebration = document.getElementById('celebration');
            
            overlay.classList.remove('show');
            celebration.classList.remove('show');
            
            if (currentLevel < puzzles.length - 1) {
                loadPuzzle(currentLevel + 1);
            }
        }

        function updateStats() {
            document.getElementById('solvedCount').textContent = stats.solved;
            document.getElementById('hintsUsed').textContent = stats.hints;
            document.getElementById('attempts').textContent = stats.attempts;
        }

        function updateProgress() {
            const progress = (stats.solved / puzzles.length) * 100;
            document.getElementById('progressBar').style.width = progress + '%';
        }

        // 初期化
        init();
    </script>
</body>
</html>
