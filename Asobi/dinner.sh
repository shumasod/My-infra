#!/bin/bash

# バージョン
VERSION="2.0"

# 設定ファイルのパス
CONFIG_DIR="$HOME/.dinner_suggester"
HISTORY_FILE="$CONFIG_DIR/history.csv"
FAVORITES_FILE="$CONFIG_DIR/favorites.txt"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"

# 設定ディレクトリの作成
mkdir -p "$CONFIG_DIR" 2>/dev/null

# 端末の色サポートを確認
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    ORANGE='\033[0;33m'
    BOLD='\033[1m'
    DIM='\033[2m'
    UNDERLINE='\033[4m'
    NC='\033[0m'    # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    ORANGE=''
    BOLD=''
    DIM=''
    UNDERLINE=''
    NC=''
fi

# カテゴリー別のメニュー配列
declare -A menu_categories

menu_categories["和食"]=(
    "寿司:1000:高タンパク:魚介類:30分:★★★★☆"
    "天ぷら:800:高カロリー:小麦:40分:★★★★★"
    "うどん:600:中カロリー:小麦:15分:★★★☆☆"
    "そば:600:低カロリー:そば:15分:★★★☆☆"
    "親子丼:800:高タンパク:卵:20分:★★★★☆"
    "カツ丼:900:高カロリー:豚肉,小麦:25分:★★★★☆"
    "すき焼き:1500:高タンパク:牛肉:40分:★★★★★"
    "しゃぶしゃぶ:1500:高タンパク:豚肉,牛肉:30分:★★★★☆"
    "牛丼:500:高タンパク:牛肉:10分:★★★☆☆"
    "唐揚げ定食:850:高カロリー:鶏肉,小麦:25分:★★★★☆"
    "焼き魚定食:900:高タンパク:魚介類:20分:★★★☆☆"
    "お好み焼き:750:中カロリー:小麦,卵:30分:★★★★☆"
    "おにぎり:300:低カロリー:なし:5分:★★☆☆☆"
    "たこ焼き:600:中カロリー:小麦:25分:★★★☆☆"
    "豚汁定食:700:中カロリー:豚肉:20分:★★★☆☆"
    "鍋焼きうどん:800:中カロリー:小麦:15分:★★★☆☆"
    "ちらし寿司:950:中カロリー:魚介類:30分:★★★★☆"
    "天丼:900:高カロリー:小麦,えび:20分:★★★★☆"
    "味噌カツ定食:950:高カロリー:豚肉,小麦:25分:★★★★☆"
    "海鮮丼:1200:高タンパク:魚介類:15分:★★★★☆"
)

menu_categories["中華"]=(
    "ラーメン:800:高カロリー:小麦:15分:★★★★☆"
    "餃子セット:700:中カロリー:豚肉,小麦:25分:★★★★☆"
    "麻婆豆腐定食:800:中カロリー:大豆:20分:★★★★☆"
    "チャーハン:700:中カロリー:卵:15分:★★★☆☆"
    "八宝菜定食:900:中カロリー:えび:30分:★★★☆☆"
    "担々麺:900:高カロリー:小麦,ピーナッツ:20分:★★★★☆"
    "春巻き定食:800:高カロリー:小麦:25分:★★★☆☆"
    "酢豚定食:900:高カロリー:豚肉:30分:★★★★☆"
    "回鍋肉定食:850:高タンパク:豚肉:25分:★★★★☆"
    "天津飯:700:中カロリー:卵:20分:★★★☆☆"
    "中華丼:800:中カロリー:豚肉,えび:15分:★★★☆☆"
    "エビチリ定食:950:中カロリー:えび:25分:★★★★☆"
    "焼き餃子:500:中カロリー:豚肉,小麦:20分:★★★★☆"
    "小籠包:700:中カロリー:豚肉,小麦:30分:★★★★★"
    "広東麺:850:中カロリー:小麦:20分:★★★☆☆"
    "青椒肉絲定食:850:高タンパク:牛肉:25分:★★★★☆"
    "油淋鶏:900:高カロリー:鶏肉:30分:★★★★☆"
    "五目あんかけ焼きそば:950:中カロリー:小麦:25分:★★★★☆"
    "エビマヨ定食:950:高カロリー:えび:25分:★★★★☆"
    "麻婆茄子定食:750:中カロリー:なす:20分:★★★★☆"
)

menu_categories["洋食"]=(
    "ハンバーグ定食:900:高タンパク:牛肉:30分:★★★★★"
    "オムライス:800:中カロリー:卵:25分:★★★★☆"
    "ナポリタン:700:中カロリー:小麦:20分:★★★☆☆"
    "カルボナーラ:900:高カロリー:小麦,卵:20分:★★★★☆"
    "ビーフシチュー:1000:高タンパク:牛肉:45分:★★★★☆"
    "グラタン:800:高カロリー:乳製品:35分:★★★★☆"
    "ピザ:1000:高カロリー:小麦,乳製品:30分:★★★★★"
    "エビフライ定食:900:中カロリー:えび,小麦:25分:★★★★☆"
    "ハヤシライス:850:中カロリー:牛肉:30分:★★★★☆"
    "コロッケ定食:800:高カロリー:牛肉,小麦:25分:★★★☆☆"
    "ミートソーススパゲティ:750:中カロリー:小麦,牛肉:20分:★★★★☆"
    "ドリア:850:高カロリー:乳製品:35分:★★★★☆"
    "チキンソテー:900:高タンパク:鶏肉:25分:★★★★☆"
    "ロコモコ:850:高タンパク:牛肉,卵:20分:★★★★☆"
    "シーフードパスタ:950:中カロリー:小麦,魚介類:25分:★★★★☆"
    "ビーフストロガノフ:1100:高タンパク:牛肉,乳製品:40分:★★★★☆"
    "ステーキ定食:1500:高タンパク:牛肉:25分:★★★★★"
    "ガーリックシュリンプ:1000:中カロリー:えび:25分:★★★★☆"
    "チキンカレー:800:中カロリー:鶏肉:30分:★★★★☆"
    "フィッシュアンドチップス:850:高カロリー:魚介類,小麦:30分:★★★★☆"
)

menu_categories["アジア料理"]=(
    "タイ風グリーンカレー:900:中カロリー:鶏肉:30分:★★★★☆"
    "ビビンバ:900:中カロリー:牛肉,卵:25分:★★★★☆"
    "ケバブライス:800:高タンパク:羊肉:20分:★★★☆☆"
    "ガパオライス:900:中カロリー:鶏肉:20分:★★★★☆"
    "ナシゴレン:800:中カロリー:えび:25分:★★★★☆"
    "タコライス:800:中カロリー:牛肉:20分:★★★☆☆"
    "フォー:850:低カロリー:牛肉:25分:★★★★☆"
    "トムヤムクン:950:低カロリー:えび:30分:★★★★★"
    "タンドリーチキン:900:中カロリー:鶏肉:40分:★★★★☆"
    "サムゲタン:1100:中カロリー:鶏肉:50分:★★★★☆"
    "パッタイ:850:中カロリー:えび,ピーナッツ:25分:★★★★☆"
    "マッサマンカレー:950:中カロリー:牛肉:40分:★★★★★"
    "ココナッツミルクカレー:850:中カロリー:鶏肉:35分:★★★★☆"
    "焼肉定食:1200:高タンパク:牛肉:25分:★★★★★"
    "チヂミ:750:中カロリー:小麦:25分:★★★★☆"
    "スンドゥブチゲ:800:中カロリー:豆腐:30分:★★★★☆"
    "プルコギ丼:950:高タンパク:牛肉:25分:★★★★☆"
    "カオマンガイ:850:中カロリー:鶏肉:30分:★★★★☆"
    "ミーゴレン:800:中カロリー:小麦,えび:25分:★★★★☆"
    "ロティチャナイ:600:中カロリー:小麦:20分:★★★☆☆"
)

menu_categories["ファストフード"]=(
    "ハンバーガーセット:600:高カロリー:牛肉,小麦:5分:★★★☆☆"
    "チキンバーガーセット:650:中カロリー:鶏肉,小麦:5分:★★★☆☆"
    "フィッシュバーガーセット:700:中カロリー:魚介類,小麦:5分:★★★☆☆"
    "チキンナゲット:500:中カロリー:鶏肉:5分:★★★☆☆"
    "フライドポテト:300:高カロリー:じゃがいも:5分:★★★☆☆"
    "チキンサンド:600:中カロリー:鶏肉,小麦:5分:★★★☆☆"
    "ピザセット:900:高カロリー:小麦,乳製品:10分:★★★★☆"
    "タコス:700:中カロリー:牛肉,小麦:10分:★★★★☆"
    "ブリトー:800:中カロリー:牛肉,小麦:10分:★★★★☆"
    "ケンタッキーフライドチキン:800:高カロリー:鶏肉:5分:★★★★☆"
    "チーズバーガー:450:高カロリー:牛肉,乳製品:5分:★★★☆☆"
    "ホットドッグ:500:中カロリー:豚肉,小麦:5分:★★★☆☆"
    "フィッシュアンドチップス:750:高カロリー:魚介類,小麦:10分:★★★☆☆"
    "チリドッグ:550:中カロリー:豚肉,小麦:5分:★★★☆☆"
    "シェイク:400:高カロリー:乳製品:5分:★★★☆☆"
    "チキンウィング:600:中カロリー:鶏肉:10分:★★★★☆"
    "オニオンリング:400:中カロリー:小麦:5分:★★★☆☆"
    "シーザーサラダ:500:低カロリー:なし:5分:★★★☆☆"
    "ポテトサラダ:400:中カロリー:じゃがいも:5分:★★★☆☆"
    "コーンスープ:300:低カロリー:乳製品:5分:★★☆☆☆"
)

menu_categories["ヘルシー"]=(
    "サラダチキン:500:低カロリー,高タンパク:鶏肉:10分:★★★☆☆"
    "ベジタブルスープ:400:低カロリー:なし:20分:★★★☆☆"
    "アボカドサラダ:600:中カロリー:なし:15分:★★★★☆"
    "豆腐ステーキ:550:低カロリー:大豆:20分:★★★☆☆"
    "グリルチキンサラダ:650:低カロリー,高タンパク:鶏肉:20分:★★★★☆"
    "スムージーボウル:700:低カロリー:なし:10分:★★★★☆"
    "ひよこ豆のサラダ:550:低カロリー:なし:15分:★★★☆☆"
    "キヌアボウル:700:低カロリー:なし:25分:★★★★☆"
    "蒸し野菜のサラダ:450:低カロリー:なし:20分:★★★☆☆"
    "ベジタブルカレー:650:低カロリー:なし:30分:★★★★☆"
    "冷や奴:300:低カロリー:大豆:5分:★★☆☆☆"
    "わかめスープ:350:低カロリー:なし:10分:★★★☆☆"
    "蒸し鶏のサラダ:600:低カロリー,高タンパク:鶏肉:20分:★★★★☆"
    "野菜スティック:350:低カロリー:なし:10分:★★☆☆☆"
    "ビーンズサラダ:500:低カロリー:豆類:15分:★★★☆☆"
    "プロテインボウル:700:高タンパク:鶏肉,豆類:25分:★★★★☆"
    "フムス:450:低カロリー:ひよこ豆:15分:★★★★☆"
    "ヨーグルトパフェ:500:中カロリー:乳製品:10分:★★★★☆"
    "野菜たっぷりスープパスタ:650:中カロリー:小麦:25分:★★★★☆"
    "豆乳リゾット:600:中カロリー:なし:30分:★★★★☆"
)

menu_categories["お手軽"]=(
    "コンビニおにぎり:150:低カロリー:なし:1分:★★☆☆☆"
    "サンドイッチ:300:中カロリー:小麦:5分:★★★☆☆"
    "カップ麺:250:中カロリー:小麦:3分:★★☆☆☆"
    "コンビニ弁当:500:中カロリー:小麦:1分:★★★☆☆"
    "インスタントラーメン:300:高カロリー:小麦:5分:★★☆☆☆"
    "冷凍ピザ:600:高カロリー:小麦,乳製品:10分:★★★☆☆"
    "冷凍餃子:400:中カロリー:小麦,豚肉:10分:★★★☆☆"
    "缶詰ツナのサラダ:350:低カロリー:魚介類:5分:★★★☆☆"
    "レトルトカレー:400:中カロリー:小麦:5分:★★★☆☆"
    "フリーズドライスープ:200:低カロリー:なし:3分:★★☆☆☆"
    "チルドパスタ:450:中カロリー:小麦:7分:★★★☆☆"
    "冷凍チャーハン:400:中カロリー:卵:7分:★★★☆☆"
    "レトルトパスタソース:300:中カロリー:なし:5分:★★★☆☆"
    "冷凍グラタン:550:高カロリー:乳製品:15分:★★★☆☆"
    "即席みそ汁:100:低カロリー:なし:2分:★★☆☆☆"
    "コンビニサラダ:300:低カロリー:なし:1分:★★☆☆☆"
    "おでん:400:低カロリー:魚介類:1分:★★★☆☆"
    "冷凍たこ焼き:350:中カロリー:小麦:10分:★★★☆☆"
    "チルドスープ:250:低カロリー:なし:3分:★★★☆☆"
    "レトルト丼物:450:中カロリー:なし:3分:★★★☆☆"
)

# ランダムなコメント配列
positive_comments=(
    "美味しそう！良い選択です！"
    "これは間違いない選択です！"
    "食欲をそそりますね！"
    "とても人気のある料理です！"
    "季節にぴったりの選択です！"
    "栄養バランスも良さそうですね！"
    "これで決まりですね！"
    "私も食べたくなりました！"
    "今日の気分にぴったりの選択です！"
    "美味しさ保証付きの一品です！"
    "素敵な選択です！食事を楽しんでください！"
    "今夜の晩ごはんが楽しみになりますね！"
    "この料理で素敵な夜になりますように！"
    "とても満足感のある選択です！"
    "料理の香りが想像できますね！"
)

# 季節のおすすめコメント
seasonal_comments=(
    "この季節にぴったりの料理です！"
    "旬の食材が楽しめる一品です！"
    "季節感あふれる素敵な選択です！"
    "今の時期に特におすすめの料理です！"
    "季節の味わいを存分に楽しめます！"
)

# 曜日に応じたおすすめコメント
weekday_comments=(
    "月曜日の疲れを癒してくれる料理です！"
    "火曜日にぴったりの元気が出る一品です！"
    "水曜日の気分転換にぴったりです！"
    "木曜日の活力源になりますよ！"
    "金曜日の晩酌のお供にぴったりです！"
    "週末の始まりにふさわしい贅沢な一品です！"
    "日曜日のリラックスタイムにぴったりです！"
)

# 予算の配列と範囲
declare -A budget_ranges
budget_ranges["〜300円"]=300
budget_ranges["301円〜500円"]=500
budget_ranges["501円〜800円"]=800
budget_ranges["801円〜1000円"]=1000
budget_ranges["1001円〜1500円"]=1500
budget_ranges["1501円〜"]=9999

# 簡易レシピのデータベース
declare -A simple_recipes
simple_recipes["寿司"]="1. 酢飯を作る（米、酢、砂糖、塩）\n2. 好みの具材（刺身、野菜など）を準備\n3. 酢飯の上に具材をのせる\n4. わさび、醤油で味付け"
simple_recipes["天ぷら"]="1. 具材（海老、野菜など）を準備\n2. 天ぷら粉に水を混ぜる\n3. 具材に衣をつけて180℃の油で揚げる\n4. 天つゆと一緒に食べる"
simple_recipes["ラーメン"]="1. スープを作る（鶏がら、醤油など）\n2. 麺を茹でる\n3. 具材（チャーシュー、ねぎなど）を準備\n4. 器にスープ、麺、具材を盛り付ける"
simple_recipes["ハンバーグ"]="1. 合挽き肉に玉ねぎ、パン粉、卵を混ぜる\n2. 形を整えて両面を焼く\n3. デミグラスソースを作る\n4. ハンバーグにソースをかける"
simple_recipes["カレーライス"]="1. 肉と野菜を炒める\n2. 水を加えて煮込む\n3. カレールーを溶かし入れて煮込む\n4. ご飯と一緒に盛り付ける"

# 設定の保存
save_settings() {
    echo "# 晩ごはんサジェスター設定" > "$SETTINGS_FILE"
    echo "LAST_BUDGET=\"$LAST_BUDGET\"" >> "$SETTINGS_FILE"
    echo "LAST_CATEGORY=\"$LAST_CATEGORY\"" >> "$SETTINGS_FILE"
    echo "THEME_COLOR=\"$THEME_COLOR\"" >> "$SETTINGS_FILE"
}

# 設定の読み込み
load_settings() {
    if [ -f "$SETTINGS_FILE" ]; then
        source "$SETTINGS_FILE"
    else
        LAST_BUDGET="予算は気にしない"
        LAST_CATEGORY="おまかせ"
        THEME_COLOR="blue"
    fi
}

# 予算内のメニューをフィルタリングする関数
filter_by_budget() {
    local category="$1"
    local max_price="$2"
    local filtered_menu=()
    
    for item in "${menu_categories[$category][@]}"; do
        local name="${item%%:*}"
        local details="${item#*:}"
        local price="${details%%:*}"
        
        if [ "$price" -le "$max_price" ]; then
            filtered_menu+=("$item")
        fi
    done
    
    # 予算内のメニューがない場合は空の配列を返す
    echo "${filtered_menu[@]}"
}

# アレルギー・食材フィルタリング
filter_by_allergens() {
    local menu_list=("$@")
    local filtered_menu=()
    
    for item in "${menu_list[@]}"; do
        local name="${item%%:*}"
        local details="${item#*:}"
        local allergens=$(echo "$details" | cut -d':' -f3)
        local allergen_found=0
        
        for allergen in $ALLERGENS; do
            if [[ "$allergens" == *"$allergen"* ]]; then
                allergen_found=1
                break
            fi
        done
        
        if [ $allergen_found -eq 0 ]; then
            filtered_menu+=("$item")
        fi
    done
    
    echo "${filtered_menu[@]}"
}

# 栄養条件フィルタリング
filter_by_nutrition() {
    local menu_list=("$@")
    local filtered_menu=()
    
    for item in "${menu_list[@]}"; do
        local name="${item%%:*}"
        local details="${item#*:}"
        local nutrition=$(echo "$details" | cut -d':' -f2)
        
        if [[ "$NUTRITION" == "すべて" ]] || [[ "$nutrition" == *"$NUTRITION"* ]]; then
            filtered_menu+=("$item")
        fi
    done
    
    echo "${filtered_menu[@]}"
}

# メニュー表示関数
display_menu() {
    local item="$1"
    local name="${item%%:*}"
    local details="${item#*:}"
    local price=$(echo "$details" | cut -d':' -f1)
    local nutrition=$(echo "$details" | cut -d':' -f2)
    local allergens=$(echo "$details" | cut -d':' -f3)
    local time=$(echo "$details" | cut -d':' -f4)
    local rating=$(echo "$details" | cut -d':' -f5)
    
    echo -e "${YELLOW}[$name] ${CYAN}${price}円${NC}"
    echo -e "${DIM}栄養: ${nutrition} | アレルゲン: ${allergens} | 調理時間: ${time} | 評価: ${rating}${NC}"
}

# レシピ表示関数
display_recipe() {
    local menu_name="$1"
    
    for key in "${!simple_recipes[@]}"; do
        if [[ "$menu_name" == *"$key"* ]]; then
            echo -e "\n${PURPLE}【簡易レシピ】${NC}"
            echo -e "${simple_recipes[$key]}"
            return
        fi
    done
    
    echo -e "\n${YELLOW}このメニューの簡易レシピは登録されていません。${NC}"
}

# ランダムコメント生成関数
get_random_comment() {
    # 曜日に応じたコメント (20%の確率)
    if [ $((RANDOM % 5)) -eq 0 ]; then
        local day_of_week=$(date +%u)  # 1-7, 1は月曜日
        local comment=${weekday_comments[$((day_of_week-1))]}
        echo "$comment"
        return
    fi
    
    # 季節に応じたコメント (20%の確率)
    if [ $((RANDOM % 5)) -eq 0 ]; then
        local month=$(date +%m)  # 01-12
        local season_index=$(( (month - 1) / 3 % 4 ))  # 0:冬, 1:春, 2:夏, 3:秋
        local comment=${seasonal_comments[$season_index]}
        echo "$comment"
        return
    fi
    
    # 通常のコメント (60%の確率)
    local comments=("${positive_comments[@]}")
    echo "${comments[$RANDOM % ${#comments[@]}]}"
}

# 履歴記録関数
save_history() {
    local category="$1"
    local menu="$2"
    local price="$3"
    local date=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "$date,$category,$menu,$price円" >> "$HISTORY_FILE"
}

# 履歴表示関数
show_history() {
    if [ -f "$HISTORY_FILE" ]; then
        clear 2>/dev/null || printf "\033c"
        echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
        echo -e "${BLUE}┃           選択履歴           ┃${NC}"
        echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
        
        echo -e "${CYAN}日時\t\t\tカテゴリー\tメニュー\t価格${NC}"
        echo -e "${DIM}─────────────────────────────────────────────────${NC}"
        
        # 最新の10件を表示
        tail -n 10 "$HISTORY_FILE" | tac | while IFS=, read -r date category menu price; do
            echo -e "${date}\t${category}\t${menu}\t${price}"
        done
        
        # 履歴の統計
        echo -e "\n${PURPLE}【統計情報】${NC}"
        echo -e "${GREEN}総選択回数:${NC} $(wc -l < "$HISTORY_FILE")"
        
        # 最も選ばれたカテゴリー
        most_category=$(cut -d',' -f2 "$HISTORY_FILE" | sort | uniq -c | sort -nr | head -n1)
        echo -e "${GREEN}最も選んだカテゴリー:${NC} $(echo "$most_category" | awk '{print $2}') ($(echo "$most_category" | awk '{print $1}')回)"
        
        # 最も選ばれたメニュー
        most_menu=$(cut -d',' -f3 "$HISTORY_FILE" | sort | uniq -c | sort -nr | head -n1)
        echo -e "${GREEN}最も選んだメニュー:${NC} $(echo "$most_menu" | awk '{print $2}') ($(echo "$most_menu" | awk '{print $1}')回)"
        
        # 平均予算
        avg_price=$(awk -F, '{gsub(/円/,"",$4); sum+=$4; count++} END {print sum/count}' "$HISTORY_FILE")
        echo -e "${GREEN}平均予算:${NC} ${avg_price%.*}円"
    else
        echo -e "${YELLOW}履歴はまだありません。${NC}"
    fi
    
    echo -e "\n${CYAN}Enterキーを押して続行...${NC}"
    read -r dummy
}

# お気に入り追加関数
add_to_favorites() {
    local menu="$1"
    
    # すでに登録されているか確認
    if [ -f "$FAVORITES_FILE" ] && grep -q "^$menu$" "$FAVORITES_FILE"; then
        echo -e "${YELLOW}このメニューはすでにお気に入りに登録されています。${NC}"
        return
    fi
    
    # お気に入りに追加
    echo "$menu" >> "$FAVORITES_FILE"
    echo -e "${GREEN}「$menu」をお気に入りに追加しました！${NC}"
}

# お気に入り一覧表示関数
show_favorites() {
    if [ -f "$FAVORITES_FILE" ] && [ -s "$FAVORITES_FILE" ]; then
        clear 2>/dev/null || printf "\033c"
        echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
        echo -e "${BLUE}┃           お気に入りメニュー           ┃${NC}"
        echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
        
        local count=1
        while IFS= read -r menu; do
            echo -e "${YELLOW}$count)${NC} $menu"
            count=$((count+1))
        done < "$FAVORITES_FILE"
    else
        echo -e "${YELLOW}お気に入りはまだ登録されていません。${NC}"
    fi
    
    echo -e "\n${CYAN}Enterキーを押して続行...${NC}"
    read -r dummy
}

# 設定画面
show_settings_menu() {
    while true; do
        clear 2>/dev/null || printf "\033c"
        echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
        echo -e "${BLUE}┃              設定メニュー              ┃${NC}"
        echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
        
        echo -e "${GREEN}1) アレルギー設定${NC}"
        echo -e "${GREEN}2) 栄養条件設定${NC}"
        echo -e "${GREEN}3) テーマカラー変更${NC}"
        echo -e "${GREEN}4) 履歴のクリア${NC}"
        echo -e "${GREEN}5) お気に入りのクリア${NC}"
        echo -e "${GREEN}6) 戻る${NC}\n"
        
        read -p "選択してください (1-6): " setting_choice
        
        case $setting_choice in
            1)
                set_allergies
                ;;
            2)
                set_nutrition
                ;;
            3)
                set_theme_color
                ;;
            4)
                echo -e "\n${YELLOW}本当に履歴をクリアしますか？ (y/n)${NC}"
                read -n 1 -r confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    rm -f "$HISTORY_FILE"
                    echo -e "\n${GREEN}履歴をクリアしました。${NC}"
                fi
                sleep 2
                ;;
            5)
                echo -e "\n${YELLOW}本当にお気に入りをクリアしますか？ (y/n)${NC}"
                read -n 1 -r confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    rm -f "$FAVORITES_FILE"
                    echo -e "\n${GREEN}お気に入りをクリアしました。${NC}"
                fi
                sleep 2
                ;;
            6)
                return
                ;;
            *)
                echo -e "\n${RED}無効な選択です。${NC}"
                sleep 1
                ;;
        esac
    done
}

# アレルギー設定
set_allergies() {
    clear 2>/dev/null || printf "\033c"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃             アレルギー設定             ┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${YELLOW}避けたい食材を選択してください（複数選択可、スペース区切り）${NC}"
    echo -e "1) 小麦   2) 卵   3) 乳製品   4) 大豆"
    echo -e "5) 魚介類 6) えび 7) ピーナッツ 8) なし\n"
    
    read -p "選択 (例: 1 3 6): " allergen_choices
    
    ALLERGENS=""
    for choice in $allergen_choices; do
        case $choice in
            1) ALLERGENS="$ALLERGENS 小麦" ;;
            2) ALLERGENS="$ALLERGENS 卵" ;;
            3) ALLERGENS="$ALLERGENS 乳製品" ;;
            4) ALLERGENS="$ALLERGENS 大豆" ;;
            5) ALLERGENS="$ALLERGENS 魚介類" ;;
            6) ALLERGENS="$ALLERGENS えび" ;;
            7) ALLERGENS="$ALLERGENS ピーナッツ" ;;
            8) ALLERGENS="" ; break ;;
        esac
    done
    
    echo -e "\n${GREEN}アレルギー設定を保存しました: $ALLERGENS${NC}"
    sleep 2
}

# 栄養条件設定
set_nutrition() {
    clear 2>/dev/null || printf "\033c"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃             栄養条件設定               ┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${YELLOW}希望する栄養条件を選択してください${NC}"
    echo -e "1) 低カロリー"
    echo -e "2) 中カロリー"
    echo -e "3) 高カロリー"
    echo -e "4) 高タンパク"
    echo -e "5) すべて\n"
    
    read -p "選択 (1-5): " nutrition_choice
    
    case $nutrition_choice in
        1) NUTRITION="低カロリー" ;;
        2) NUTRITION="中カロリー" ;;
        3) NUTRITION="高カロリー" ;;
        4) NUTRITION="高タンパク" ;;
        5) NUTRITION="すべて" ;;
        *) NUTRITION="すべて" ;;
    esac
    
    echo -e "\n${GREEN}栄養条件を設定しました: $NUTRITION${NC}"
    sleep 2
}

# テーマカラー設定
set_theme_color() {
    clear 2>/dev/null || printf "\033c"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃            テーマカラー設定            ┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${YELLOW}テーマカラーを選択してください${NC}"
    echo -e "${BLUE}1) ブルー${NC}"
    echo -e "${GREEN}2) グリーン${NC}"
    echo -e "${PURPLE}3) パープル${NC}"
    echo -e "${CYAN}4) シアン${NC}"
    echo -e "${ORANGE}5) オレンジ${NC}\n"
    
    read -p "選択 (1-5): " color_choice
    
    case $color_choice in
        1) THEME_COLOR="blue" ;;
        2) THEME_COLOR="green" ;;
        3) THEME_COLOR="purple" ;;
        4) THEME_COLOR="cyan" ;;
        5) THEME_COLOR="orange" ;;
        *) THEME_COLOR="blue" ;;
    esac
    
    # 設定を保存
    save_settings
    
    echo -e "\n${GREEN}テーマカラーを変更しました: $THEME_COLOR${NC}"
    sleep 2
}

# ヘルプ表示
show_help() {
    clear 2>/dev/null || printf "\033c"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃              ヘルプ情報                ┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${YELLOW}【今日の晩ごはんサジェスター v$VERSION】${NC}\n"
    echo -e "${GREEN}このプログラムでできること:${NC}"
    echo -e "- 予算と好みに合わせた晩ごはんの提案"
    echo -e "- 栄養情報やアレルギー情報を考慮したメニュー選択"
    echo -e "- 料理の評価や調理時間の表示"
    echo -e "- 選択履歴の記録と統計表示"
    echo -e "- お気に入りメニューの管理"
    echo -e "- 簡易レシピの表示"
    echo -e "- 季節や曜日に合わせたおすすめ"
    
    echo -e "\n${GREEN}使い方:${NC}"
    echo -e "1. メインメニューから「晩ごはんを提案してもらう」を選択"
    echo -e "2. 予算とジャンルを指定"
    echo -e "3. 提案されたメニューを評価"
    echo -e "4. 気に入ったらお気に入りに登録"
    
    echo -e "\n${GREEN}設定について:${NC}"
    echo -e "- アレルギー設定: 避けたい食材を指定"
    echo -e "- 栄養条件設定: カロリーやタンパク質量の条件を選択"
    echo -e "- テーマカラー: インターフェースの色合いを変更"
    
    echo -e "\n${CYAN}Enterキーを押して続行...${NC}"
    read -r dummy
}

# テーマカラーの適用
apply_theme_color() {
    case $THEME_COLOR in
        "green")
            HEADER_COLOR=$GREEN
            ;;
        "purple")
            HEADER_COLOR=$PURPLE
            ;;
        "cyan")
            HEADER_COLOR=$CYAN
            ;;
        "orange")
            HEADER_COLOR=$ORANGE
            ;;
        *)
            HEADER_COLOR=$BLUE
            ;;
    esac
}

# 初期化（設定の読み込み）
init() {
    load_settings
    apply_theme_color
    
    # デフォルト値の設定
    if [ -z "$ALLERGENS" ]; then
        ALLERGENS=""
    fi
    
    if [ -z "$NUTRITION" ]; then
        NUTRITION="すべて"
    fi
}

# ASCII アートのロゴ表示
show_logo() {
    echo -e "${HEADER_COLOR}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${HEADER_COLOR}┃                                                      ┃${NC}"
    echo -e "${HEADER_COLOR}┃  ▄▄▄▄    ▄▄▄       ███▄    █   ▄████  ▒█████       ┃${NC}"
    echo -e "${HEADER_COLOR}┃ ▓█████▄ ▒████▄     ██ ▀█   █  ██▒ ▀█▒▒██▒  ██▒     ┃${NC}"
    echo -e "${HEADER_COLOR}┃ ▒██▒ ▄██▒██  ▀█▄  ▓██  ▀█ ██▒▒██░▄▄▄░▒██░  ██▒     ┃${NC}"
    echo -e "${HEADER_COLOR}┃ ▒██░█▀  ░██▄▄▄▄██ ▓██▒  ▐▌██▒░▓█  ██▓▒██   ██░     ┃${NC}"
    echo -e "${HEADER_COLOR}┃ ░▓█  ▀█▓ ▓█   ▓██▒▒██░   ▓██░░▒▓███▀▒░ ████▓▒░     ┃${NC}"
    echo -e "${HEADER_COLOR}┃                                                      ┃${NC}"
    echo -e "${HEADER_COLOR}┃         今日の晩ごはんサジェスター v$VERSION          ┃${NC}"
    echo -e "${HEADER_COLOR}┃                                                      ┃${NC}"
    echo -e "${HEADER_COLOR}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
}

# メイン関数
main() {
    init
    
    while true; do
        clear 2>/dev/null || printf "\033c"
        show_logo
        
        # メインメニュー
        echo -e "${GREEN}何をしますか？${NC}"
        echo -e "1) 晩ごはんを提案してもらう"
        echo -e "2) 履歴を確認する"
        echo -e "3) お気に入りを確認する"
        echo -e "4) 設定"
        echo -e "5) ヘルプ"
        echo -e "6) 終了\n"
        
        # 条件表示
        if [ -n "$ALLERGENS" ]; then
            echo -e "${DIM}アレルギー除外: $ALLERGENS${NC}"
        fi
        if [ "$NUTRITION" != "すべて" ]; then
            echo -e "${DIM}栄養条件: $NUTRITION${NC}"
        fi
        echo ""
        
        read -p "選択してください (1-6): " main_choice
        
        case $main_choice in
            1) suggest_dinner ;;
            2) 
                show_history
                ;;
            3)
                show_favorites
                ;;
            4)
                show_settings_menu
                ;;
            5)
                show_help
                ;;
            6) 
                echo -e "\n${YELLOW}またご利用ください！良い食事を！${NC}"
                exit 0 
                ;;
            *) 
                echo -e "\n${RED}無効な選択です。もう一度試してください。${NC}"
                sleep 1
                ;;
        esac
    done
}

# 晩ごはん提案関数
suggest_dinner() {
    clear 2>/dev/null || printf "\033c"
    echo -e "${HEADER_COLOR}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${HEADER_COLOR}┃       今日の晩ごはんサジェスター       ┃${NC}"
    echo -e "${HEADER_COLOR}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    # 予算の確認
    echo -e "${GREEN}予算を教えてください：${NC}"
    local options=("〜300円" "301円〜500円" "501円〜800円" "801円〜1000円" "1001円〜1500円" "1501円〜" "予算は気にしない")
    
    # 前回の選択を強調表示
    for i in "${!options[@]}"; do
        if [ "${options[$i]}" = "$LAST_BUDGET" ]; then
            echo -e "$((i+1))) ${BOLD}${options[$i]}${NC} (前回の選択)"
        else
            echo -e "$((i+1))) ${options[$i]}"
        fi
    done
    echo ""
    
    read -p "選択してください (1-7): " budget_choice
    
    case $budget_choice in
        1) budget="〜300円" ;;
        2) budget="301円〜500円" ;;
        3) budget="501円〜800円" ;;
        4) budget="801円〜1000円" ;;
        5) budget="1001円〜1500円" ;;
        6) budget="1501円〜" ;;
        7) budget="予算は気にしない" ;;
        *) 
            echo -e "\n${RED}無効な選択です。デフォルトを使用します。${NC}"
            budget="$LAST_BUDGET"
            sleep 1
            ;;
    esac
    
    # 予算を保存
    LAST_BUDGET="$budget"
    save_settings
    
    # メニューカテゴリーの表示
    echo -e "\n${GREEN}食べたい料理のジャンルを選んでください：${NC}"
    echo -e "1) 和食"
    echo -e "2) 中華"
    echo -e "3) 洋食"
    echo -e "4) アジア料理"
    echo -e "5) ファストフード"
    echo -e "6) ヘルシー"
    echo -e "7) お手軽"
    echo -e "8) お気に入りから"
    echo -e "9) おまかせ"
    echo -e "0) 戻る\n"
    
    read -p "選択してください (0-9): " choice
    
    case $choice in
        1) category="和食" ;;
        2) category="中華" ;;
        3) category="洋食" ;;
        4) category="アジア料理" ;;
        5) category="ファストフード" ;;
        6) category="ヘルシー" ;;
        7) category="お手軽" ;;
        8) 
            if [ -f "$FAVORITES_FILE" ] && [ -s "$FAVORITES_FILE" ]; then
                category="お気に入り"
            else
                echo -e "\n${YELLOW}お気に入りはまだ登録されていません。おまかせで提案します。${NC}"
                sleep 2
                categories=("和食" "中華" "洋食" "アジア料理" "ファストフード" "ヘルシー" "お手軽")
                category=${categories[$RANDOM % ${#categories[@]}]}
            fi
            ;;
        9) 
            categories=("和食" "中華" "洋食" "アジア料理" "ファストフード" "ヘルシー" "お手軽")
            category=${categories[$RANDOM % ${#categories[@]}]}
            ;;
        0) 
            main
            return
            ;;
        *) 
            echo -e "\n${RED}無効な選択です。もう一度試してください。${NC}"
            sleep 1
            suggest_dinner
            return
            ;;
    esac
    
    # カテゴリーを保存
    LAST_CATEGORY="$category"
    save_settings
    
    # お気に入りから選択の場合
    if [ "$category" = "お気に入り" ]; then
        suggest_from_favorites "$budget"
        return
    fi
    
    # 予算でフィルタリング
    if [ "$budget" != "予算は気にしない" ]; then
        max_price=${budget_ranges["$budget"]}
        filtered_menu=($(filter_by_budget "$category" "$max_price"))
        
        # 予算内のメニューがない場合
        if [ ${#filtered_menu[@]} -eq 0 ]; then
            echo -e "\n${RED}申し訳ありません。その予算内の${category}メニューがありません。${NC}"
            sleep 2
            suggest_dinner
            return
        fi
        
        # アレルギーでフィルタリング（設定されている場合）
        if [ -n "$ALLERGENS" ]; then
            filtered_menu=($(filter_by_allergens "${filtered_menu[@]}"))
            if [ ${#filtered_menu[@]} -eq 0 ]; then
                echo -e "\n${RED}申し訳ありません。条件に合うメニューがありません。アレルギー設定を見直してください。${NC}"
                sleep 2
                suggest_dinner
                return
            fi
        fi
        
        # 栄養条件でフィルタリング
        if [ "$NUTRITION" != "すべて" ]; then
            filtered_menu=($(filter_by_nutrition "${filtered_menu[@]}"))
            if [ ${#filtered_menu[@]} -eq 0 ]; then
                echo -e "\n${RED}申し訳ありません。条件に合うメニューがありません。栄養条件を見直してください。${NC}"
                sleep 2
                suggest_dinner
                return
            fi
        fi
        
        # 選択されたカテゴリーと予算からランダムにメニューを選択
        random_item=${filtered_menu[$RANDOM % ${#filtered_menu[@]}]}
    else
        # 予算を気にしない場合は全メニューから選択
        selected_array=("${menu_categories[$category][@]}")
        
        # アレルギーでフィルタリング（設定されている場合）
        if [ -n "$ALLERGENS" ]; then
            selected_array=($(filter_by_allergens "${selected_array[@]}"))
            if [ ${#selected_array[@]} -eq 0 ]; then
                echo -e "\n${RED}申し訳ありません。条件に合うメニューがありません。アレルギー設定を見直してください。${NC}"
                sleep 2
                suggest_dinner
                return
            fi
        fi
        
        # 栄養条件でフィルタリング
        if [ "$NUTRITION" != "すべて" ]; then
            selected_array=($(filter_by_nutrition "${selected_array[@]}"))
            if [ ${#selected_array[@]} -eq 0 ]; then
                echo -e "\n${RED}申し訳ありません。条件に合うメニューがありません。栄養条件を見直してください。${NC}"
                sleep 2
                suggest_dinner
                return
            fi
        fi
        
        random_item=${selected_array[$RANDOM % ${#selected_array[@]}]}
    fi
    
    # メニュー情報を分解
    menu_name="${random_item%%:*}"
    details="${random_item#*:}"
    menu_price="${details%%:*}"
    
    # 結果を表示（ドラムロール効果付き）
    clear 2>/dev/null || printf "\033c"
    echo -e "${HEADER_COLOR}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${HEADER_COLOR}┃           メニュー提案中               ┃${NC}"
    echo -e "${HEADER_COLOR}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${YELLOW}ジャンル: $category${NC}"
    echo -e "${CYAN}予算: $budget${NC}"
    
    echo -e "\n${GREEN}あなたにぴったりのメニューを探しています...${NC}"
    
    # ドラムロール効果
    for i in {1..3}; do
        echo -n "."
        sleep 0.5
    done
    
    # 結果表示
    clear 2>/dev/null || printf "\033c"
    echo -e "${HEADER_COLOR}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${HEADER_COLOR}┃           あなたの晩ごはん           ┃${NC}"
    echo -e "${HEADER_COLOR}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${PURPLE}【提案メニュー】${NC}"
    echo -e "${YELLOW}ジャンル: $category${NC}"
    display_menu "$random_item"
    
    # 簡易レシピの表示
    display_recipe "$menu_name"
    
    # ランダムコメントの表示
    echo -e "\n${GREEN}$(get_random_comment)${NC}\n"
    
    # メニューの評価オプション
    echo -e "${GREEN}このメニューはいかがですか？${NC}"
    echo "1) 良いね！これにする！"
    echo "2) お気に入りに追加する"
    echo "3) 別のを見てみたい"
    echo "4) カテゴリーを変更する"
    echo "5) メインメニューに戻る"
    read -p "選択してください (1-5): " rating
    
    case $rating in
        1) 
            # 履歴に保存
            save_history "$category" "$menu_name" "$menu_price"
            
            # 食事タイマーのオプション
            echo -e "\n${YELLOW}調理タイマーを設定しますか？ (y/n)${NC}"
            read -n 1 -r timer_option
            if [[ $timer_option =~ ^[Yy]$ ]]; then
                set_cooking_timer "$random_item"
            else
                echo -e "\n${GREEN}素敵な選択ですね！良い食事を！${NC}"
                sleep 2
                exit 0
            fi
            ;;
        2)
            add_to_favorites "$menu_name"
            sleep 2
            # 同じカテゴリーで再提案
            suggest_dinner_same_category "$category" "$budget"
            ;;
        3) 
            echo -e "${YELLOW}では、別のメニューを提案します！${NC}"
            sleep 1
            # 同じカテゴリーで再提案
            suggest_dinner_same_category "$category" "$budget"
            ;;
        4) 
            echo -e "${YELLOW}カテゴリーを変更します。${NC}"
            sleep 1
            suggest_dinner
            ;;
        5)
            main
            ;;
    esac
}

# お気に入りからの提案
suggest_from_favorites() {
    local budget="$1"
    local favorite_menus=()
    
    # お気に入りリストからメニュー名を取得
    while IFS= read -r menu_name; do
        favorite_menus+=("$menu_name")
    done < "$FAVORITES_FILE"
    
    # ランダムに選択
    local selected_menu=${favorite_menus[$RANDOM % ${#favorite_menus[@]}]}
    
    # 結果を表示
    clear 2>/dev/null || printf "\033c"
    echo -e "${HEADER_COLOR}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${HEADER_COLOR}┃           あなたの晩ごはん           ┃${NC}"
    echo -e "${HEADER_COLOR}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${PURPLE}【お気に入りから提案】${NC}"
    echo -e "${YELLOW}メニュー: $selected_menu${NC}"
    
    # ランダムコメントの表示
    echo -e "\n${GREEN}$(get_random_comment)${NC}\n"
    
    # メニューの評価オプション
    echo -e "${GREEN}このメニューはいかがですか？${NC}"
    echo "1) 良いね！これにする！"
    echo "2) 別のお気に入りを見てみたい"
    echo "3) カテゴリーを変更する"
    echo "4) メインメニューに戻る"
    read -p "選択してください (1-4): " rating
    
    case $rating in
        1) 
            # 履歴に保存
            save_history "お気に入り" "$selected_menu" "不明"
            
            echo -e "\n${GREEN}素敵な選択ですね！良い食事を！${NC}"
            sleep 2
            exit 0
            ;;
        2) 
            echo -e "${YELLOW}では、別のお気に入りメニューを提案します！${NC}"
            sleep 1
            suggest_from_favorites "$budget"
            ;;
        3) 
            echo -e "${YELLOW}カテゴリーを変更します。${NC}"
            sleep 1
            suggest_dinner
            ;;
        4)
            main
            ;;
    esac
}

# 調理タイマー設定
set_cooking_timer() {
    local item="$1"
    local details="${item#*:}"
    local time=$(echo "$details" | cut -d':' -f4)
    local minutes=${time%分}
    
    clear 2>/dev/null || printf "\033c"
    echo -e "${HEADER_COLOR}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${HEADER_COLOR}┃             調理タイマー               ┃${NC}"
    echo -e "${HEADER_COLOR}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${YELLOW}推奨調理時間は約${minutes}分です。${NC}"
    echo -e "${GREEN}タイマーを何分にセットしますか？${NC}"
    read -p "分数を入力（0で取り消し）: " timer_minutes
    
    if [ "$timer_minutes" = "0" ]; then
        echo -e "\n${YELLOW}タイマーをキャンセルしました。良い食事を！${NC}"
        sleep 2
        exit 0
    fi
    
    if ! [[ "$timer_minutes" =~ ^[0-9]+$ ]]; then
        echo -e "\n${RED}無効な時間です。タイマーをキャンセルします。${NC}"
        sleep 2
        exit 0
    fi
    
    echo -e "\n${GREEN}${timer_minutes}分のタイマーをセットしました！${NC}"
    echo -e "${YELLOW}調理の準備をどうぞ...${NC}\n"
    
    # カウントダウン
    local total_seconds=$((timer_minutes * 60))
    local remaining=$total_seconds
    
    while [ $remaining -gt 0 ]; do
        # 残り時間の計算
        local mins=$((remaining / 60))
        local secs=$((remaining % 60))
        
        # プログレスバーの表示
        local progress=$((20 * (total_seconds - remaining) / total_seconds))
        echo -ne "\r[${CYAN}"
        for ((i=0; i<progress; i++)); do
            echo -ne "="
        done
        echo -ne ">${NC}"
        for ((i=progress; i<20; i++)); do
            echo -ne " "
        done
        echo -ne "] ${mins}分 ${secs}秒 残り"
        
        sleep 1
        remaining=$((remaining - 1))
    done
    
    # タイマー終了
    echo -e "\n\n${GREEN}時間になりました！良い食事を！${NC}"
    
    # ベル音（端末がサポートしている場合）
    for i in {1..3}; do
        echo -ne "\a"
        sleep 0.5
    done
    
    exit 0
}

# 同じカテゴリーで再提案
suggest_dinner_same_category() {
    local category="$1"
    local budget="$2"
    
    clear 2>/dev/null || printf "\033c"
    echo -e "${HEADER_COLOR}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${HEADER_COLOR}┃       今日の晩ごはんサジェスター       ┃${NC}"
    echo -e "${HEADER_COLOR}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    # お気に入りから選択の場合
    if [ "$category" = "お気に入り" ]; then
        suggest_from_favorites "$budget"
        return
    fi
    
    # 予算でフィルタリング
    if [ "$budget" != "予算は気にしない" ]; then
        max_price=${budget_ranges["$budget"]}
        filtered_menu=($(filter_by_budget "$category" "$max_price"))
        
        # 予算内のメニューがない場合（これは通常起こらないはず）
        if [ ${#filtered_menu[@]} -eq 0 ]; then
            echo -e "\n${RED}申し訳ありません。その予算内の${category}メニューがありません。${NC}"
            sleep 2
            suggest_dinner
            return
        fi
        
        # アレルギーでフィルタリング（設定されている場合）
        if [ -n "$ALLERGENS" ]; then
            filtered_menu=($(filter_by_allergens "${filtered_menu[@]}"))
            if [ ${#filtered_menu[@]} -eq 0 ]; then
                echo -e "\n${RED}申し訳ありません。条件に合うメニューがありません。アレルギー設定を見直してください。${NC}"
                sleep 2
                suggest_dinner
                return
            fi
        fi
        
        # 栄養条件でフィルタリング
        if [ "$NUTRITION" != "すべて" ]; then
            filtered_menu=($(filter_by_nutrition "${filtered_menu[@]}"))
            if [ ${#filtered_menu[@]} -eq 0 ]; then
                echo -e "\n${RED}申し訳ありません。条件に合うメニューがありません。栄養条件を見直してください。${NC}"
                sleep 2
                suggest_dinner
                return
            fi
        fi
        
        # 選択されたカテゴリーと予算からランダムにメニューを選択
        random_item=${filtered_menu[$RANDOM % ${#filtered_menu[@]}]}
    else
        # 予算を気にしない場合は全メニューから選択
        selected_array=("${menu_categories[$category][@]}")
        
        # アレルギーでフィルタリング（設定されている場合）
        if [ -n "$ALLERGENS" ]; then
            selected_array=($(filter_by_allergens "${selected_array[@]}"))
        fi
        
        # 栄養条件でフィルタリング
        if [ "$NUTRITION" != "すべて" ]; then
            selected_array=($(filter_by_nutrition "${selected_array[@]}"))
        fi
        
        random_item=${selected_array[$RANDOM % ${#selected_array[@]}]}
    fi
    
    # メニュー情報を分解
    menu_name="${random_item%%:*}"
    details="${random_item#*:}"
    menu_price="${details%%:*}"
    
    # ドラムロール効果
    echo -e "${YELLOW}ジャンル: $category${NC}"
    echo -e "${CYAN}予算: $budget${NC}"
    echo -e "\n${GREEN}新しい提案を用意しています...${NC}"
    
    for i in {1..3}; do
        echo -n "."
        sleep 0.3
    done
    
    # 結果を表示
    clear 2>/dev/null || printf "\033c"
    echo -e "${HEADER_COLOR}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${HEADER_COLOR}┃           あなたの晩ごはん           ┃${NC}"
    echo -e "${HEADER_COLOR}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${PURPLE}【新しい提案メニュー】${NC}"
    echo -e "${YELLOW}ジャンル: $category${NC}"
    display_menu "$random_item"
    
    # 簡易レシピの表示
    display_recipe "$menu_name"
    
    # ランダムコメントの表示
    echo -e "\n${GREEN}$(get_random_comment)${NC}\n"
    
    # メニューの評価オプション
    echo -e "${GREEN}このメニューはいかがですか？${NC}"
    echo "1) 良いね！これにする！"
    echo "2) お気に入りに追加する"
    echo "3) 別のを見てみたい"
    echo "4) カテゴリーを変更する"
    echo "5) メインメニューに戻る"
    read -p "選択してください (1-5): " rating
    
    case $rating in
        1) 
            # 履歴に保存
            save_history "$category" "$menu_name" "$menu_price"
            
            # 食事タイマーのオプション
            echo -e "\n${YELLOW}調理タイマーを設定しますか？ (y/n)${NC}"
            read -n 1 -r timer_option
            if [[ $timer_option =~ ^[Yy]$ ]]; then
                set_cooking_timer "$random_item"
            else
                echo -e "\n${GREEN}素敵な選択ですね！良い食事を！${NC}"
                sleep 2
                exit 0
            fi
            ;;
        2)
            add_to_favorites "$menu_name"
            sleep 2
            suggest_dinner_same_category "$category" "$budget"
            ;;
        3) 
            echo -e "${YELLOW}では、別のメニューを提案します！${NC}"
            sleep 1
            suggest_dinner_same_category "$category" "$budget"
            ;;
        4) 
            echo -e "${YELLOW}カテゴリーを変更します。${NC}"
            sleep 1
            suggest_dinner
            ;;
        5)
            main
            ;;
    esac
}

# スクリプトを開始
main
