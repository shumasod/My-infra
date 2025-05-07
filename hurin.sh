#!/bin/bash

# =================================================================
# シェルスクリプト学習用サンプル: 「人間関係診断ジョークプログラム」
# 作成日: 2025年5月7日
# 目的: シェルスクリプトの基本構造、関数、配列、条件分岐の学習
# =================================================================

# 免責事項と同意確認
clear
echo "=================================================="
echo "【注意】このプログラムは完全にフィクションです"
echo "このスクリプトは技術学習とユーモア目的のみで作成された"
echo "サンプルプログラムです。実際の人間関係の判断には"
echo "決して使用しないでください。"
echo "=================================================="

# 変数の初期化
relationship_score=0
affair_score=0
relationship_max_score=0
affair_max_score=0

# 入力値の正規化関数（シンプル化）
normalize_answer() {
  local input=$1
  case "$input" in
    はい|はい。)
      echo "はい"
      ;;
    *)
      echo "いいえ"
      ;;
  esac
}

# 明示的な同意確認
echo "このプログラムはフィクションであり、実際の判断に使用しないことに同意しますか？"
read -p "(はい/いいえ): " consent
if [[ "$(normalize_answer "$consent")" != "はい" ]]; then
  echo "同意が得られなかったため終了します。"
  exit 1
fi

# 質問関数
ask_question() {
  local question=$1
  local relationship_weight=$2
  local affair_weight=$3
  
  relationship_max_score=$((relationship_max_score + relationship_weight))
  affair_max_score=$((affair_max_score + affair_weight))
  
  while true; do
    read -p "$question (はい/いいえ): " raw_answer
    answer=$(normalize_answer "$raw_answer")
    
    if [[ "$answer" == "はい" || "$answer" == "いいえ" ]]; then
      break
    else
      echo "「はい」または「いいえ」でお答えください。"
    fi
  done
  
  if [[ "$answer" == "はい" ]]; then
    relationship_score=$((relationship_score + relationship_weight))
    affair_score=$((affair_score + affair_weight))
  fi
}

# メイン関数
main() {
  echo "人間関係診断ジョークプログラムへようこそ！"
  echo "このプログラムは純粋に娯楽・学習用です。"
  echo "----------------"

  # 基本情報の収集
  read -p "架空の人物名を入力してください: " name

  # 性別入力のバリデーション
  while true; do
    read -p "性別を入力してください (男性/女性/その他): " gender
    if [[ "$gender" =~ ^(男性|女性|その他)$ ]]; then
      break
    else
      echo "性別は「男性」「女性」「その他」から選んで入力してください。"
    fi
  done

  # 年齢入力のバリデーション
  while true; do
    read -p "年齢を入力してください: " age
    if [[ "$age" =~ ^[0-9]+$ ]]; then
      break
    else
      echo "年齢は数字で入力してください。"
    fi
  done

  # 婚姻状態の確認
  while true; do
    read -p "婚姻状態を入力してください (既婚/未婚): " raw_married_status
    married_status=$(normalize_answer "$raw_married_status")
    if [[ "$married_status" == "はい" || "$married_status" == "いいえ" ]]; then
      break
    else
      echo "「はい」または「いいえ」でお答えください。（はい=既婚、いいえ=未婚）"
    fi
  done

  # 行動パターンの分析
  echo "以下の質問に「はい」または「いいえ」で答えてください。"
  echo "これは架空の状況に対するシナリオです。"

  # 質問とウェイトを配列で管理
  questions=(
    "対象者は最近、予定が急に変更されることが増えましたか？"
    "対象者は頻繁に携帯電話を確認しますか？"
    "対象者は特定の日や時間に必ず連絡が取れなくなりますか？"
    "対象者は最近、外見に気を使うようになりましたか？"
    "対象者はSNSでの投稿内容や頻度が変わりましたか？"
    "対象者は特定の名前や人物について話すのを避けますか？"
    "対象者は休日や特別な日に予定があると言いますか？"
    "対象者の持ち物に見覚えのないものがありますか？"
    "対象者は仕事関連の予定や出張が増えましたか？"
    "対象者の携帯電話のパスワードが最近変更されましたか？"
  )
  
  relationship_weights=(5 3 7 4 4 6 5 8 2 4)
  affair_weights=(7 6 9 6 3 8 8 9 7 9)
  
  # 配列を使って質問を処理
  for i in "${!questions[@]}"; do
    ask_question "${questions[$i]}" "${relationship_weights[$i]}" "${affair_weights[$i]}"
  done

  # 結果の分析
  relationship_percentage=$((relationship_score * 100 / relationship_max_score))
  affair_percentage=$((affair_score * 100 / affair_max_score))

  echo "----------------"
  echo "※これはフィクションの分析結果です※"
  echo "${name}さんの関係性スコア: $relationship_score / $relationship_max_score (${relationship_percentage}%)"
  
  if [[ "$married_status" == "はい" ]]; then
    echo "${name}さんの別の関係性スコア: $affair_score / $affair_max_score (${affair_percentage}%)"
  fi

  # ジョーク結果（あえてコミカルな表現に）
  echo ""
  echo "★ジョーク診断結果★"
  if [ $relationship_percentage -ge 70 ]; then
    echo "架空の${name}さんは、誰かと深い関係にあるかもしれませんね！"
  elif [ $relationship_percentage -ge 40 ]; then
    echo "架空の${name}さんは、今ちょっと怪しい動きをしています...？"
  else
    echo "架空の${name}さんは、恋愛よりも自分の時間を大切にしているようです。"
  fi

  # 学習ポイント表示
  echo "----------------"
  echo "【シェルスクリプト学習ポイント】"
  echo "1. 配列活用: questions[]配列で質問を管理"
  echo "2. 関数設計: normalize_answer()で入力処理を共通化"
  echo "3. 入力検証: while文とregexで入力値を検証"
  echo "4. 変数スコープ: local変数を活用した関数設計"
  echo "----------------"
  echo "このスクリプトは教育目的です。実際の人間関係分析には使用しないでください。"
}

# メイン関数の実行
main
