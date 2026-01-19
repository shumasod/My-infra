#!/bin/bash

# 香辛料管理スクリプト

# 設定
DB_FILE="$HOME/spice_inventory.csv"
LOG_FILE="$HOME/spice_usage.log"
SHOPPING_LIST="$HOME/spice_shopping.txt"

# ヘッダーが存在しない場合は作成
if [ ! -f "$DB_FILE" ]; then
    echo "名前,量,単位,最終使用日,残量(%),購入日,消費期限" > "$DB_FILE"
fi

# ヘルプメッセージ
function show_help {
    echo "香辛料管理システム"
    echo "使用法: $0 [コマンド] [オプション]"
    echo ""
    echo "コマンド:"
    echo "  list              全ての香辛料を表示"
    echo "  add               新しい香辛料を追加"
    echo "  use               香辛料を使用記録"
    echo "  shopping          買い物リスト表示"
    echo "  expired           期限切れの香辛料を表示"
    echo "  search [キーワード] 香辛料を検索"
    echo "  help              このヘルプを表示"
    exit 0
}

# 香辛料一覧を表示
function list_spices {
    echo "=== 香辛料一覧 ==="
    echo "残量が20%以下の香辛料は*で表示されます"
    echo ""
    
    # ヘッダー行をスキップして表示
    tail -n +2 "$DB_FILE" | sort | while IFS=, read -r name amount unit last_use remaining purchase_date expiry; do
        if [ "$(echo "$remaining < 20" | bc)" -eq 1 ]; then
            echo "* $name ($amount$unit) - 残量: ${remaining}% - 消費期限: $expiry"
        else
            echo "$name ($amount$unit) - 残量: ${remaining}% - 消費期限: $expiry"
        fi
    done
}

# 香辛料を追加
function add_spice {
    echo "=== 新しい香辛料の追加 ==="
    
    read -p "香辛料名: " name
    read -p "量: " amount
    read -p "単位 (g/ml/個): " unit
    read -p "購入日 (YYYY-MM-DD): " purchase_date
    read -p "消費期限 (YYYY-MM-DD): " expiry
    
    # 入力が空の場合のデフォルト値
    if [ -z "$purchase_date" ]; then
        purchase_date=$(date +"%Y-%m-%d")
    fi
    
    if [ -z "$expiry" ]; then
        # デフォルトで2年後
        expiry=$(date -d "+2 years" +"%Y-%m-%d")
    fi
    
    # 現在日付
    current_date=$(date +"%Y-%m-%d")
    
    # CSVに追加
    echo "$name,$amount,$unit,$current_date,100,$purchase_date,$expiry" >> "$DB_FILE"
    
    echo "追加しました: $name ($amount$unit)"
}

# 香辛料を使用
function use_spice {
    echo "=== 香辛料の使用記録 ==="
    
    # 一時ファイル
    TEMP_FILE=$(mktemp)
    
    # 香辛料一覧を番号付きで表示
    echo "使用する香辛料を選択してください:"
    counter=1
    tail -n +2 "$DB_FILE" | sort | while IFS=, read -r name amount unit last_use remaining purchase_date expiry; do
        echo "$counter) $name ($amount$unit) - 残量: ${remaining}%"
        echo "$name,$amount,$unit,$last_use,$remaining,$purchase_date,$expiry" >> "$TEMP_FILE"
        counter=$((counter + 1))
    done
    
    total_spices=$((counter - 1))
    
    # 選択
    read -p "香辛料番号を入力: " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -gt 0 ] && [ "$selection" -le "$total_spices" ]; then
        # 選択された香辛料情報
        selected=$(sed "${selection}q;d" "$TEMP_FILE")
        IFS=, read -r name amount unit last_use remaining purchase_date expiry <<< "$selected"
        
        # 使用量入力
        read -p "使用した量の割合 (%) [デフォルト: 5%]: " usage_percent
        
        # デフォルト使用量
        if [ -z "$usage_percent" ]; then
            usage_percent=5
        fi
        
        # 新しい残量を計算
        new_remaining=$(echo "$remaining - $usage_percent" | bc)
        
        # 負の値にならないようにする
        if [ "$(echo "$new_remaining < 0" | bc)" -eq 1 ]; then
            new_remaining=0
        fi
        
        # 現在日付
        current_date=$(date +"%Y-%m-%d")
        
        # データベースを更新
        sed -i "s/^$name,$amount,$unit,$last_use,$remaining,$purchase_date,$expiry$/$name,$amount,$unit,$current_date,$new_remaining,$purchase_date,$expiry/" "$DB_FILE"
        
        echo "$current_date: $name を $usage_percent% 使用しました。残量: $new_remaining%" >> "$LOG_FILE"
        echo "記録しました: $name - 残量: $new_remaining%"
        
        # 残量が20%以下なら買い物リストに追加
        if [ "$(echo "$new_remaining <= 20" | bc)" -eq 1 ]; then
            if ! grep -q "$name" "$SHOPPING_LIST"; then
                echo "$name ($amount$unit)" >> "$SHOPPING_LIST"
                echo "$name を買い物リストに追加しました"
            fi
        fi
    else
        echo "無効な選択です"
    fi
    
    # 一時ファイルを削除
    rm "$TEMP_FILE"
}

# 買い物リストを表示
function show_shopping_list {
    echo "=== 買い物リスト ==="
    
    if [ -s "$SHOPPING_LIST" ]; then
        cat "$SHOPPING_LIST"
    else
        echo "買い物リストは空です"
    fi
}

# 期限切れの香辛料を表示
function show_expired {
    echo "=== 期限切れの香辛料 ==="
    
    current_date=$(date +"%Y-%m-%d")
    
    found=0
    
    # ヘッダー行をスキップして表示
    tail -n +2 "$DB_FILE" | while IFS=, read -r name amount unit last_use remaining purchase_date expiry; do
        if [[ "$expiry" < "$current_date" ]]; then
            echo "$name - 期限切れ: $expiry"
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo "期限切れの香辛料はありません"
    fi
}

# 香辛料を検索
function search_spice {
    keyword=$1
    
    if [ -z "$keyword" ]; then
        read -p "検索キーワード: " keyword
    fi
    
    echo "=== 検索結果: $keyword ==="
    
    found=0
    
    # ヘッダー行をスキップして検索
    tail -n +2 "$DB_FILE" | grep -i "$keyword" | while IFS=, read -r name amount unit last_use remaining purchase_date expiry; do
        echo "$name ($amount$unit) - 残量: ${remaining}% - 消費期限: $expiry"
        found=1
    done
    
    if [ $found -eq 0 ]; then
        echo "「$keyword」に一致する香辛料は見つかりませんでした"
    fi
}

# コマンドライン引数がない場合はヘルプを表示
if [ $# -eq 0 ]; then
    show_help
fi

# コマンド処理
case "$1" in
    list)
        list_spices
        ;;
    add)
        add_spice
        ;;
    use)
        use_spice
        ;;
    shopping)
        show_shopping_list
        ;;
    expired)
        show_expired
        ;;
    search)
        search_spice "$2"
        ;;
    help)
        show_help
        ;;
    *)
        echo "不明なコマンド: $1"
        show_help
        ;;
esac
