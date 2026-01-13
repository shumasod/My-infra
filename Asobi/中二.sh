#!/bin/bash

# 中二病シェルスクリプト
# ～ 封印されし黒き炎の記憶 ～

BLACK='\033[0;30m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 闇のエフェクト
darkness() {
    for i in {1..3}; do
        echo -ne "${PURPLE}。${NC}"
        sleep 0.3
    done
    echo
}

# 覚醒演出
awaken() {
    echo -e "${RED}"
    echo "    ╔═══════════════════════════════════╗"
    echo "    ║  ！！！覚 醒！！！  ║"
    echo "    ╚═══════════════════════════════════╝"
    echo -e "${NC}"
    sleep 1
}

# 詠唱
chant() {
    echo -e "${CYAN}「$1」${NC}"
    sleep 1.5
}

clear
echo -e "${PURPLE}"
cat << 'EOF'
╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮
│                                           │
│    第七章 ～ 漆黒の堕天使の目覚め ～     │
│                                           │
│     The Awakening of Dark Fallen Angel    │
│                                           │
╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯
EOF
echo -e "${NC}"
sleep 2

echo -e "\n${WHITE}俺の名は...${NC}"
darkness
echo -e "${RED}漆黒の堕天使 ダークネス・ブレイド・XIII${NC}"
echo -e "${WHITE}（本名：田中一郎 17歳 高校2年生）${NC}"
sleep 2

echo -e "\n${PURPLE}ふっ...また右腕が疼きやがる...${NC}"
sleep 1
echo -e "${WHITE}（昨日の体育でドッジボール受け損ねた）${NC}"
sleep 2

echo
chant "静まれ...俺の右腕よ..."
chant "貴様の『混沌の炎（カオス・フレイム）』はまだ解放する時ではない..."
echo -e "${WHITE}（ただの筋肉痛です）${NC}"
sleep 2

awaken

echo -e "${PURPLE}くっ...封印が...解けていく...！${NC}"
darkness

echo -e "\n${RED}━━━━ 黒歴史ステータス ━━━━${NC}"
echo -e "名前：${CYAN}ダークネス・ブレイド・XIII${NC}"
echo -e "称号：${PURPLE}『虚無を統べし者』『第七の使徒』${NC}"
echo -e "必殺技：${RED}漆黒の終焉剣（ダーク・エンド・カリバー）${NC}"
echo -e "弱点：${WHITE}お母さんの「ご飯よー」${NC}"
sleep 3

echo -e "\n${CYAN}詠唱開始...${NC}\n"
sleep 1

chant "我は闇..."
chant "闇こそが我..."
chant "混沌の深淵より来たりて..."
chant "汝に永遠の眠りを与えん..."

echo -e "\n${RED}喰らえ！！${NC}"
sleep 0.5

echo -e "${PURPLE}"
cat << 'EOF'

    ╋━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╋
    ┃                                ┃
    ┃   漆 黒 の 終 焉 剣 ！！！    ┃
    ┃                                ┃
    ┃   D A R K   E N D             ┃
    ┃       C A L I B U R ！！      ┃
    ┃                                ┃
    ╋━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╋

            ＼＼٩(๑`^´๑)۶／／

EOF
echo -e "${NC}"
sleep 2

echo -e "${WHITE}「一郎ー！ご飯できたわよー！」${NC}"
sleep 1
echo -e "${PURPLE}...ちっ、邪魔が入ったか${NC}"
sleep 1
echo -e "${WHITE}「ハンバーグよー！」${NC}"
sleep 0.5
echo -e "${RED}今行くーーー！！${NC}"
sleep 2

echo -e "\n${PURPLE}"
cat << 'EOF'
╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮
│                                    │
│    ～ 続く...かもしれない ～       │
│                                    │
│    ※この物語はフィクションです    │
│    ※田中一郎くん(17)は元気です    │
│                                    │
╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯
EOF
echo -e "${NC}"

echo -e "\n${WHITE}【黒歴史度】${NC}"
echo -ne "["
for i in {1..20}; do
    echo -ne "${RED}█${NC}"
    sleep 0.1
done
echo -e "] ${RED}MAX！！${NC}"
echo -e "${WHITE}※10年後に思い出して布団の中で悶絶するレベル${NC}\n"
