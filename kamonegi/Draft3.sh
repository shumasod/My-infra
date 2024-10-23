#!/bin/bash

# 関数定義
say() {
    echo "$1"  # テキストをコンソールに表示
}

# 分量調整関数
adjust_ingredients() {
    local n=$1
    for ingredient in "${!ingredients[@]}"; do
        ingredients[$ingredient]=$((ingredients[$ingredient] * n))
    done
}

# メイン処理
main() {
    # 材料
    declare -A ingredients=(
        ["うどん"]=1
        ["鴨肉"]=50
        ["九条ネギ"]=1
        ["だし汁"]=300
    )

    # 作り方
    steps=(
        "鍋にだし汁を入れて沸騰させる。"
        "うどんを袋から取り出し、鍋に入れる。"
        "うどんが柔らかくなったら、鴨肉と九条ネギを加える。"
        "温まったら、器に盛り付けて完成。"
    )

    # 人数
    read -p "人数を入力してください: " n

    # 分量調整
    adjust_ingredients "$n"

    # 音声読み上げ
    say "鴨葱うどんの作り方を始めます。"

    # 調理開始
    for step in "${steps[@]}"; do
        echo "$step"
        say "$step"

        # 調理
        if [[ "$step" == "鍋にだし汁を入れて沸騰させる。" ]]; then
            sleep 30
        elif [[ "$step" == "うどんを袋から取り出し、鍋に入れる。" ]]; then
            sleep 30
        elif [[ "$step" == "うどんが柔らかくなったら、鴨肉と九条ネギを加える。" ]]; then
            sleep 30
        elif [[ "$step" == "温まったら、器に盛り付けて完成。" ]]; then
            sleep 10
        fi
    done

    # 音声読み上げ
    say "鴨葱うどんの完成です。"
}

# メイン処理の実行
main
