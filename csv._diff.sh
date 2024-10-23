# CSV ファイルのパス
$csvPath = "C:\temp\test.csv"
# テキストファイルのパス
$txtPath = "C:\temp\test.txt"

# ヘッダー行を含めるかどうかのフラグ
$includeHeader = $true
# 改行コードを指定する（デフォルトは環境に応じた改行コード）
$newLineChar = [Environment]::NewLine

# オプションの引数を処理する
foreach ($arg in $args) {
    if ($arg -eq "-NoHeader") {
        $includeHeader = $false
    }
    elseif ($arg -match "^-NewLineChar:(.+)$") {
        $newLineChar = $matches[1]
    }
}

# CSV ファイルを読み込む
$csvData = Get-Content $csvPath | Select-Object -Skip 1 # ヘッダー行をスキップ

# ヘッダー行を取得
$header = (Get-Content $csvPath -TotalCount 1).Split(',')

# テキストデータを格納する配列
$txtDataArray = @()

# ヘッダー行を含める場合
if ($includeHeader) {
    $txtDataArray += $header -join "`t"
}

# データ行を処理
foreach ($line in $csvData) {
    $txtDataArray += $line.Replace(',', "`t")
}

# テキストデータを結合
$txtData = $txtDataArray -join $newLineChar

# テキストファイルを保存する
$txtData | Out-File -FilePath $txtPath -Encoding utf8

Write-Output "CSV ファイルがテキストファイルに変換されました。"
