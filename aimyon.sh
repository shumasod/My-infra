#!/bin/bash

# あいみょんの代表的な曲リスト
songs=(
    "マリーゴールド: https://open.spotify.com/track/5ubD1Yi6bDB9gCallDtntx"
    "裸の心: https://open.spotify.com/track/2e7Wy9koVb8KzzMNyym31Y"
    "君はロックを聴かない: https://open.spotify.com/track/6gZkbmPH3YgTVuTZB7Yv1z"
    "ハルノヒ: https://open.spotify.com/track/2HxiYDniEcTrIdswPBIzbn"
    "愛を伝えたいだとか: https://open.spotify.com/track/7EQJU9mfTInY2eyNzi3oHp"
)

# ランダムに1曲選ぶ
random_song=${songs[$RANDOM % ${#songs[@]}]}

# 曲名とSpotifyリンクを表示
echo "🎶 今日のあいみょんのおすすめ曲 🎶"
echo $random_song

# スクリプト終了
