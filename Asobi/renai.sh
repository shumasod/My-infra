#!/bin/bash

# 恋愛関係検出スクリプト - 改良版
# 作成日: 2025年5月7日

# 免責事項と注意書き
echo "================================================"
echo "【注意】このプログラムは完全にフィクションです"
echo "このスクリプトは娯楽目的のみを意図しています。"
echo "他者のプライバシーを尊重し、実際の判断には"
echo "直接的なコミュニケーションをお勧めします。"
echo "================================================"

# 変数の初期化
relationship_score=0
max_score=0

# 入力値の正規化関数
normalize_answer() {
  local input=$1
  case "$input" in
    はい|YES|yes|Yes|はい。|Y|y)
      echo "はい"
      ;;
    *)
      echo "いいえ"
      ;;
  esac
}

# 質問関数
ask_question() {
  local question=$1
  local weight=$2
  max_score=$((max_score + weight))
  
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
    relationship_score=$((relationship_score + weight))
  fi
}

# メイン関数
main() {
  echo "恋愛関係検出プログラムへようこそ！"
  echo "このスクリプトは対象者が交際している可能性を分析します。"
  echo "----------------"

  # 基本情報の収集
  read -p "対象者の名前を入力してください: " name

  # 性別入力のバリデーション
  while true; do
    read -p "対象者の性別を入力してください (男性/女性/その他): " gender
    if [[ "$gender" =~ ^(男性|女性|その他)$ ]]; then
      break
    else
      echo "性別は「男性」「女性」「その他」から選んで入力してください。"
    fi
  done

  # 年齢入力のバリデーション
  while true; do
    read -p "対象者の年齢を入力してください: " age
    if [[ "$age" =~ ^[0-9]+$ ]]; then
      break
    else
      echo "年齢は数字で入力してください。"
    fi
  done

  # 行動パターンの分析
  echo "以下の質問に「はい」または「いいえ」で答えてください。"

  # 交際の可能性を示す質問と重み付け
  ask_question "対象者は最近、予定が急に変更されることが増えましたか？" 5
  ask_question "対象者は頻繁に携帯電話を確認しますか？" 3
  ask_question "対象者は特定の日や時間に必ず連絡が取れなくなりますか？" 7
  ask_question "対象者は最近、外見に気を使うようになりましたか？" 4
  ask_question "対象者はSNSでの投稿内容や頻度が変わりましたか？" 4
  ask_question "対象者は特定の名前や人物について話すのを避けますか？" 6
  ask_question "対象者は休日や特別な日に予定があると言いますか？" 5
  ask_question "対象者の持ち物に見覚えのないものがありますか？" 8
  ask_question "対象者の友人グループに最近変化がありましたか？" 3
  ask_question "対象者は恋愛に関する話題に対して反応が変わりましたか？" 6

  # 結果の分析
  percentage=$((relationship_score * 100 / max_score))

  echo "----------------"
  echo "分析結果:"
  echo "${name}さんの交際の可能性スコア: $relationship_score / $max_score (${percentage}%)"

  if [ $percentage -ge 70 ]; then
    echo "判定: 交際している可能性が非常に高いです。"
  elif [ $percentage -ge 40 ]; then
    echo "判定: 交際している可能性があります。さらなる観察が必要です。"
  else
    echo "判定: 交際している可能性は低いと思われます。"
  fi

  echo "----------------"
  echo "再度注意: このスクリプトは娯楽目的であり、実際の判断には不適切です。"
  echo "他者のプライバシーを尊重し、不必要な詮索は控えましょう。"
}

# メイン関数の実行
main
