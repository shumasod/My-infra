#!/bin/bash

# 壁紙が格納されているディレクトリのパス
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# サポートする画像形式
IMAGE_FORMATS=("jpg" "jpeg" "png" "bmp")

# ランダムに壁紙を選択する関数
select_random_wallpaper() {
    wallpapers=()
    for format in "${IMAGE_FORMATS[@]}"; do
        wallpapers+=($(find "$WALLPAPER_DIR" -type f -iname "*.$format"))
    done
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        echo "エラー: 壁紙が見つかりません。" >&2
        exit 1
    fi
    
    random_index=$((RANDOM % ${#wallpapers[@]}))
    echo "${wallpapers[$random_index]}"
}

# デスクトップ環境を検出する関数
detect_desktop_environment() {
    if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
        echo "GNOME"
    elif [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
        echo "KDE"
    elif [ "$XDG_CURRENT_DESKTOP" = "XFCE" ]; then
        echo "XFCE"
    else
        echo "UNKNOWN"
    fi
}

# 壁紙を設定する関数
set_wallpaper() {
    local wallpaper="$1"
    local desktop_env=$(detect_desktop_environment)
    
    case "$desktop_env" in
        "GNOME")
            gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper"
            ;;
        "KDE")
            qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                var allDesktops = desktops();
                for (i=0; i<allDesktops.length; i++) {
                    d = allDesktops[i];
                    d.wallpaperPlugin = 'org.kde.image';
                    d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
                    d.writeConfig('Image', 'file://$wallpaper');
                }"
            ;;
        "XFCE")
            xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$wallpaper"
            ;;
        *)
            echo "エラー: サポートされていないデスクトップ環境です。" >&2
            exit 1
            ;;
    esac
}

# メイン処理
main() {
    wallpaper=$(select_random_wallpaper)
    set_wallpaper "$wallpaper"
    echo "壁紙を変更しました: $wallpaper"
}

# スクリプトの実行
main
