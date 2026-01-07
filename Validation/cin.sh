#!/bin/bash

# AI会話シミュレーションシェルスクリプト
# 作成日: 2025年5月19日

# 色の設定
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# バナーの表示
display_banner() {
    clear
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}    AI会話シミュレーター v1.0    ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo -e "終了するには 'exit' または 'quit' と入力してください。\n"
}

# ランダムな思考時間のシミュレーション
simulate_thinking() {
    echo -n "思考中"
    for i in {1..3}; do
        echo -n "."
        sleep 0.5
    done
    echo ""
}

# レスポンスデータベース
get_response() {
    local input=$1
    local response=""
    
    # 入力を小文字に変換して比較
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # 時間関連
    if [[ "$input_lower" == *"時間"* ]] || [[ "$input_lower" == *"何時"* ]]; then
        response="現在の時刻は $(date +%H:%M:%S) です。"
    
    # 日付関連
    elif [[ "$input_lower" == *"日付"* ]] || [[ "$input_lower" == *"今日"* ]]; then
        response="今日は $(date +%Y年%m月%d日) です。"
    
    # 挨拶関連
    elif [[ "$input_lower" == *"こんにちは"* ]] || [[ "$input_lower" == *"hello"* ]]; then
        response="こんにちは！何かお手伝いできることはありますか？"
    
    elif [[ "$input_lower" == *"おはよう"* ]]; then
        response="おはようございます！今日も素晴らしい一日になりますように。"
    
    elif [[ "$input_lower" == *"こんばんは"* ]]; then
        response="こんばんは。夜分にどのようなご用件でしょうか？"
    
    # 感情関連
    elif [[ "$input_lower" == *"元気"* ]]; then
        response="私はプログラムなので感情はありませんが、あなたのお役に立てることを願っています。あなたはいかがお過ごしですか？"
    
    # 名前関連
    elif [[ "$input_lower" == *"名前"* ]]; then
        response="私はシェルAIと申します。シンプルなシェルスクリプトでAI会話をシミュレートしています。"
    
    # 能力関連
    elif [[ "$input_lower" == *"できる"* ]]; then
        response="私は基本的な会話応答、時間や日付の表示などができます。より複雑な機能はこのスクリプトに実装されていません。"
    
    # 天気関連
    elif [[ "$input_lower" == *"天気"* ]]; then
        response="申し訳ありませんが、天気情報にアクセスする機能は実装されていません。"
    
    # ヘルプ関連
    elif [[ "$input_lower" == *"ヘルプ"* ]] || [[ "$input_lower" == *"help"* ]]; then
        response="私に話しかけるだけで会話が始まります。日付、時間、挨拶などに応答できます。終了するには 'exit' または 'quit' と入力してください。"
    
    # 感謝関連
    elif [[ "$input_lower" == *"ありがとう"* ]] || [[ "$input_lower" == *"thank"* ]]; then
        response="どういたしまして！他に何かお手伝いできることはありますか？"
    
    # 別れの挨拶
    elif [[ "$input_lower" == *"さようなら"* ]] || [[ "$input_lower" == *"bye"* ]]; then
        response="さようなら。またのご利用をお待ちしております。"
        
    # それ以外のパターン
    else
        # ランダムレスポンス
        random_responses=(
            "興味深い質問ですね。もう少し詳しく教えていただけますか？"
            "申し訳ありませんが、その質問に対する適切な応答が見つかりません。"
            "なるほど、理解しました。他に何かご質問はありますか？"
            "その点については、まだ学習過程にあります。"
            "ご質問ありがとうございます。別の角度から質問していただくと、より良い回答ができるかもしれません。"
        )
        response=${random_responses[$RANDOM % ${#random_responses[@]}]}
    fi
    
    echo "$response"
}

# メイン会話ループ
main() {
    display_banner
    
    while true; do
        # ユーザー入力を取得
        echo -e "${GREEN}ユーザー:${NC} \c"
        read user_input
        
        # 終了コマンドの確認
        if [[ "$user_input" == "exit" ]] || [[ "$user_input" == "quit" ]]; then
            echo -e "${BLUE}AI:${NC} ご利用ありがとうございました。さようなら！"
            break
        fi
        
        # 空の入力をスキップ
        if [[ -z "$user_input" ]]; then
            continue
        fi
        
        # AI応答の生成
        simulate_thinking
        response=$(get_response "$user_input")
        echo -e "${BLUE}AI:${NC} $response"
        echo ""
    done
}

# スクリプトの実行
main
