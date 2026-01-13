# 色の定義
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Blue = [System.ConsoleColor]::Blue

# アスキーアートを表示する関数
function Show-AsciiArt {
    $Host.UI.RawUI.ForegroundColor = $Blue
    Write-Host "          ##   ##  ##   ##  ######    #####    #####   ###  ##"
    Write-Host "          ##   ##  ##   ##   ##  ##  ##   ##  ##   ##   ##  ##"
    Write-Host "  #####   ##   ##  ##   ##   ##  ##  ##   ##  ##   ##   ## ##"
    Write-Host " ##       #######  ##   ##   #####   ##   ##  ##   ##   ####"
    Write-Host "  #####   ##   ##  ##   ##   ##  ##  ##   ##  ##   ##   ## ##"
    Write-Host "      ##  ##   ##  ##   ##   ##  ##  ##   ##  ##   ##   ##  ##"
    Write-Host " ######   ##   ##   #####   ######    #####    #####   ###  ##"
    $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
}

# 情報入力を受け付ける関数
function Get-UserInfo {
    $Host.UI.RawUI.ForegroundColor = $Green
    Write-Host "あなたの情報を入力してください"
    $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
    
    $script:name = Read-Host "お名前"
    $script:age = Read-Host "年齢"
    $script:hobby = Read-Host "趣味"
    $script:food = Read-Host "好きな食べ物"
}

# 自己紹介を表示する関数
function Show-Introduction {
    Clear-Host
    Show-AsciiArt
    
    $Host.UI.RawUI.ForegroundColor = $Red
    Write-Host "＊＊＊ 自己紹介 ＊＊＊"
    $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
    
    Write-Host ""
    $Host.UI.RawUI.ForegroundColor = $Green
    Write-Host "名前: $name"
    Write-Host "年齢: $age 歳"
    Write-Host "趣味: $hobby"
    Write-Host "好きな食べ物: $food"
    $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
    Write-Host ""
}

# メイン処理
Clear-Host
Show-AsciiArt
Get-UserInfo
Show-Introduction

Write-Host "`n" -NoNewline
$Host.UI.RawUI.ForegroundColor = $Green
Write-Host "Enterキーを押すと終了します"
$Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
Read-Host
