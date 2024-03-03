# CSV ファイルのパス
$csvPath = "C:\temp\test.csv"

# テキストファイルのパス
$txtPath = "C:\temp\test.txt"

# CSV ファイルを読み込む
$csvData = Import-Csv $csvPath

# ヘッダー行を含めるかどうかのフラグ
$includeHeader = $true

# 改行コードを指定する
$newLineChar = "`r`n"  # デフォルトは Windows の改行コード

# オプションの引数を処理する
$args = $args | ForEach-Object {
    if ($_ -eq "-NoHeader") {
        $includeHeader = $false
    }
    elseif ($_ -match "-NewLineChar:(.+)") {
        $newLineChar = $matches[1]
    }
}

# ヘッダー行を含める場合
if ($includeHeader) {
    $txtData = ($csvData | ConvertTo-Text) -join $newLineChar
}
else {
    $txtData = ($csvData | Select-Object -Skip 1 | ConvertTo-Text) -join $newLineChar
}

# テキストファイルを保存する
$txtData | Out-File -FilePath $txtPath -Encoding utf8

Write-Output "CSV ファイルがテキストファイルに変換されました。"


