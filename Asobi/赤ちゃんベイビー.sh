#!/bin/bash

# 赤ちゃんシェルスクリプト
# ～ 生後8ヶ月のたっくんの1日 ～

PINK='\033[1;35m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

# 赤ちゃんの状態
HUNGER=50
SLEEPY=30
MOOD=80
DIAPER=100

# 赤ちゃんの顔
baby_face() {
    case $1 in
        "happy")
            echo -e "${PINK}"
            cat << 'EOF'
        ＿＿＿
      ／ ・ω・ ＼  ばぶー！
     ｜   ▽   ｜
      ＼＿＿＿／
        ｜｜
EOF
            ;;
        "cry")
            echo -e "${CYAN}"
            cat << 'EOF'
        ＿＿＿
      ／ ＞﹏＜ ＼  ふえぇぇぇん！！
     ｜  。 。 ｜  
      ＼＿▽＿／
        ｜｜
EOF
            ;;
        "sleep")
            echo -e "${WHITE}"
            cat << 'EOF'
        ＿＿＿
      ／ －ω－ ＼  すぴー...
     ｜   ω   ｜  💤
      ＼＿＿＿／
        ｜｜
EOF
            ;;
        "angry")
            echo -e "${RED}"
            cat << 'EOF'
        ＿＿＿
      ／ `Д´  ＼  あ゛ーー！！
     ｜   △   ｜
      ＼＿＿＿／
        ｜｜
EOF
            ;;
        "eating")
            echo -e "${YELLOW}"
            cat << 'EOF'
        ＿＿＿
      ／ ＾ω＾ ＼  もぐもぐ
     ｜  🍼   ｜
      ＼＿＿＿／
        ｜｜
EOF
            ;;
    esac
    echo -e "${NC}"
}

# 赤ちゃん語
baby_talk() {
    local words=("ばぶ" "あうあう" "まんま" "だー" "うきゃ" "あぶー" "んまんま" "きゃっきゃ")
    echo "${words[$RANDOM % ${#words[@]}]}"
}

# ステータス表示
show_status() {
    echo -e "\n${WHITE}━━━ たっくん(8ヶ月)のステータス ━━━${NC}"
    
    echo -ne "おなか ："
    for ((i=0; i<HUNGER; i+=10)); do echo -ne "${YELLOW}🍼${NC}"; done
    echo " ($HUNGER%)"
    
    echo -ne "ねむけ ："
    for ((i=0; i<SLEEPY; i+=10)); do echo -ne "${CYAN}💤${NC}"; done
    echo " ($SLEEPY%)"
    
    echo -ne "ごきげん："
    for ((i=0; i<MOOD; i+=10)); do echo -ne "${PINK}💕${NC}"; done
    echo " ($MOOD%)"
    
    echo -ne "おむつ ："
    for ((i=0; i<DIAPER; i+=10)); do echo -ne "${GREEN}✨${NC}"; done
    echo " ($DIAPER%)"
    echo
}

# イベント
event_milk() {
    echo -e "${YELLOW}【ミルクタイム】${NC}"
    baby_face "eating"
    echo "ごくごく...ごくごく..."
    sleep 1
    echo -e "たっくん「$(baby_talk)！$(baby_talk)！」"
    HUNGER=$((HUNGER + 30))
    [[ $HUNGER -gt 100 ]] && HUNGER=100
    MOOD=$((MOOD + 10))
    [[ $MOOD -gt 100 ]] && MOOD=100
    sleep 1
}

event_play() {
    echo -e "${PINK}【あそびタイム】${NC}"
    echo "ママ「いないいない...」"
    sleep 1
    echo "ママ「ばあっ！」"
    sleep 0.5
    baby_face "happy"
    echo -e "たっくん「きゃっきゃっきゃ！！」"
    echo
    echo "  🧸 おもちゃをポイッ"
    echo "  ママ「あっ」"
    echo "  🧸 また拾ってもらう"
    echo "  たっくん「$(baby_talk)！」（もっかい！）"
    echo "  🧸 またポイッ"
    echo "  ママ「...」"
    MOOD=$((MOOD + 20))
    [[ $MOOD -gt 100 ]] && MOOD=100
    SLEEPY=$((SLEEPY + 20))
    sleep 1
}

event_cry() {
    echo -e "${CYAN}【なぜか泣く】${NC}"
    baby_face "cry"
    echo "たっくん「ふえぇぇぇぇん！！えーん！えーん！」"
    sleep 1
    echo "ママ「どうしたの〜？おなか？ねむい？おむつ？」"
    echo "たっくん「ふええぇぇぇ...」"
    sleep 1
    echo "パパ「抱っこしてみる？」"
    echo "（抱っこする）"
    sleep 1
    baby_face "happy"
    echo "たっくん「...$(baby_talk)」"
    echo "パパ「泣き止んだ！なんだったんだ...」"
    echo -e "${WHITE}※理由は本人もわかってない${NC}"
    sleep 1
}

event_diaper() {
    echo -e "${GREEN}【おむつタイム】${NC}"
    echo "ママ「あれ？なんかにおう...」"
    sleep 1
    baby_face "happy"
    echo "たっくん「$(baby_talk)〜♪」（すっきり！）"
    echo
    echo "ママ「おむつ確認...あっ」"
    echo -e "${YELLOW}💩 大物発見 💩${NC}"
    sleep 1
    echo "ママ「はいはい、キレイキレイしようね〜」"
    echo "たっくん「あうあうあー」（足バタバタ）"
    echo "ママ「動かないでー！」"
    DIAPER=100
    sleep 1
}

event_sleep() {
    echo -e "${WHITE}【ねんねタイム】${NC}"
    echo "ママ「ねんねんころりよ〜♪」"
    sleep 1
    echo "たっくん「.........」"
    sleep 1
    baby_face "sleep"
    echo "すぴー...すぴー..."
    sleep 1
    echo
    echo -e "${YELLOW}【30分後】${NC}"
    echo "ママ「やっと寝た...お茶でも...」"
    echo "（そーっと立ち上がる）"
    sleep 1
    echo -e "${RED}ピキッ${NC}（床が鳴る）"
    sleep 0.5
    baby_face "cry"
    echo "たっくん「ふぎゃあああああ！！」"
    echo "ママ「」"
    SLEEPY=0
    sleep 1
}

event_food() {
    echo -e "${YELLOW}【離乳食タイム】${NC}"
    echo "ママ「はーい、にんじんのペーストだよ〜」"
    echo "たっくん「...」"
    sleep 1
    echo "（スプーンを近づける）"
    baby_face "angry"
    echo "たっくん「んーーー！！」（顔そむける）"
    sleep 1
    echo "ママ「おいしいよ〜？ほら〜」"
    echo "（口に入れる）"
    sleep 0.5
    echo "たっくん「...もぐ...」"
    echo
    echo -e "${RED}ぶーーーーっ${NC}"
    echo
    echo "🥕💦 ← ママの顔"
    echo
    echo "ママ「...」"
    baby_face "happy"
    echo "たっくん「きゃっきゃ！」"
    echo -e "${WHITE}※本人は大満足${NC}"
    sleep 1
}

# メイン
clear
echo -e "${PINK}"
cat << 'EOF'
╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮
│                                    │
│    👶 たっくんの１にち 👶         │
│                                    │
│    ～ 生後8ヶ月 男の子 ～         │
│                                    │
╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯
EOF
echo -e "${NC}"
sleep 2

baby_face "happy"
echo -e "たっくん「$(baby_talk)！」（おはよう！）"
echo
sleep 2

# 1日のイベント
events=("event_milk" "event_play" "event_cry" "event_diaper" "event_food" "event_sleep")

for event in "${events[@]}"; do
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    $event
    show_status
    echo
    echo -e "${WHITE}（Enterで次へ...）${NC}"
    read -r
done

# エンディング
clear
echo -e "${PINK}"
cat << 'EOF'

    ╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮
    │                                 │
    │   👶 たっくん、今日もがんばった │
    │                                 │
    ╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯

           すやすや...💤

            ＿＿＿
          ／ －ω－ ＼
         ｜   ω   ｜
          ＼＿＿＿／
         ___｜｜___
        |  ふかふか  |
        |＿＿＿＿＿＿|

EOF
echo -e "${NC}"

echo -e "${WHITE}━━━ 今日のまとめ ━━━${NC}"
echo "・ミルク 5回"
echo "・おむつ交換 8回"
echo "・謎の号泣 3回"
echo "・離乳食べーされた回数 2回"
echo "・ママの睡眠時間 4時間（細切れ）"
echo
echo -e "${YELLOW}ママ・パパ、今日もおつかれさまでした！${NC}"
echo -e "${PINK}たっくん「ばぶー！」（ありがと！）${NC}"
echo
