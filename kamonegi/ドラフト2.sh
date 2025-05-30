#!/bin/bash

# 高速うどん表示関数（ネットワーク不要のASCIIアート版）
show_kamonegi() {
    cat << 'EOF'
    ╔══════════════════════════════════╗
    ║        🦆 鴨葱うどん 🥢          ║
    ╚══════════════════════════════════╝
    
         ～～～～～～～～～～～
        (  あつあつのだし汁  )
         ～～～～～～～～～～～
            🦆   ╭─╮   🟢
           鴨肉  │麺│  ネギ
                 ╰─╯
    
    【具材】うどん・鴨肉・九条ネギ・だし汁
    【調理時間】約15分
    【カロリー】約420kcal
    
    【簡単レシピ】
    1. だし汁を沸騰させる
    2. うどんを茹でる(冷凍なら3分)
    3. 鴨肉を炒めて追加
    4. ネギを散らして完成！
    
    いただきます！ 🍜✨
EOF
}

# メニュー選択機能付き高速版
show_udon_menu() {
    local recipes=(
        "鴨葱うどん:show_kamonegi"
        "きつねうどん:show_kitsune" 
        "天ぷらうどん:show_tempura"
        "月見うどん:show_tsukimi"
    )
    
    echo "═══ 🍜 うどんメニュー 🍜 ═══"
    for i in "${!recipes[@]}"; do
        echo "$((i+1)). ${recipes[i]%:*}"
    done
    
    read -p "選択してください (1-${#recipes[@]}): " choice
    
    if [[ $choice =~ ^[1-4]$ ]]; then
        ${recipes[$((choice-1))]#*:}
    else
        echo "❌ 無効な選択です"
    fi
}

# その他のうどん関数（軽量版）
show_kitsune() {
    echo "🦊 きつねうどん - 甘辛いお揚げがたまらない！"
}

show_tempura() {
    echo "🍤 天ぷらうどん - サクサク天ぷらでボリューム満点！"
}

show_tsukimi() {
    echo "🌙 月見うどん - とろ〜り卵で月夜気分♪"
}

# メイン実行
main() {
    case "${1:-menu}" in
        "kamonegi"|"鴨葱") show_kamonegi ;;
        "menu"|"") show_udon_menu ;;
        *) echo "使用法: $0 [kamonegi|menu]" ;;
    esac
}

main "$@"