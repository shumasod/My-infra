#!/bin/bash

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# プレイヤーの初期状態
player_hp=100
player_attack=20
level=1
exp=0

# ゲームオーバー関数
game_over() {
    echo -e "${RED}ゲームオーバー！あなたは倒れました。${NC}"
    exit 0
}

# 戦闘関数
battle() {
    enemy_name=$1
    enemy_hp=$2
    enemy_attack=$3

    echo -e "${YELLOW}$enemy_name が現れた！${NC}"
    
    while true; do
        echo "プレイヤーHP: $player_hp | 敵HP: $enemy_hp"
        echo "1) 攻撃 2) 回復"
        read -p "行動を選択してください: " choice

        case $choice in
            1)
                damage=$((RANDOM % player_attack + 1))
                enemy_hp=$((enemy_hp - damage))
                echo -e "${GREEN}あなたは$damageのダメージを与えた！${NC}"
                ;;
            2)
                heal=$((RANDOM % 20 + 10))
                player_hp=$((player_hp + heal))
                echo -e "${BLUE}あなたは${heal}回復した！${NC}"
                ;;
            *)
                echo "無効な選択です。"
                continue
                ;;
        esac

        if [ $enemy_hp -le 0 ]; then
            echo -e "${GREEN}$enemy_nameを倒した！${NC}"
            exp=$((exp + 10))
            break
        fi

        enemy_damage=$((RANDOM % enemy_attack + 1))
        player_hp=$((player_hp - enemy_damage))
        echo -e "${RED}$enemy_nameから${enemy_damage}のダメージを受けた！${NC}"

        if [ $player_hp -le 0 ]; then
            game_over
        fi
    done
}

# メイン・ゲームループ
while true; do
    clear
    echo -e "${BLUE}===== 忍者ゲーム - レベル $level =====${NC}"
    echo "HP: $player_hp | 攻撃力: $player_attack | 経験値: $exp"
    echo "1) 次の階層に進む"
    echo "2) 修行する（HPと攻撃力を上げる）"
    echo "3) 終了する"
    read -p "選択してください: " choice

    case $choice in
        1)
            enemy_type=$((RANDOM % 3))
            case $enemy_type in
                0)
                    battle "雑魚忍者" $((30 + level * 5)) $((10 + level * 2))
                    ;;
                1)
                    battle "中忍" $((50 + level * 7)) $((15 + level * 3))
                    ;;
                2)
                    battle "上忍" $((70 + level * 10)) $((20 + level * 4))
                    ;;
            esac
            ;;
        2)
            player_hp=$((player_hp + 20))
            player_attack=$((player_attack + 5))
            echo -e "${GREEN}修行を積んだ！HPと攻撃力が上がった！${NC}"
            ;;
        3)
            echo "ゲームを終了します。"
            exit 0
            ;;
        *)
            echo "無効な選択です。"
            ;;
    esac

    if [ $exp -ge $((level * 20)) ]; then
        level=$((level + 1))
        exp=0
        player_hp=$((player_hp + 30))
        player_attack=$((player_attack + 10))
        echo -e "${YELLOW}レベルアップ！レベル${level}になった！${NC}"
    fi

    read -p "Enterキーを押して続ける"
done
