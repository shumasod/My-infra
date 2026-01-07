# パラメータの定義
param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [string]$InputDelimiter = ',',
    
    [string]$OutputDelimiter = "`t",  # Excelで開きやすいようにタブをデフォルトに
    
    [string]$InputEncoding = 'utf8',
    
    [string]$OutputEncoding = 'utf8BOM',  # Excelで文字化けしないようにBOM付きUTF-8をデフォルトに
    
    [switch]$NoHeader,
    
    [string]$NewLineChar = [Environment]::NewLine,
    
    [int]$HeaderRowIndex = 0,
    
    [switch]$ExcelFormat  # Excel最適化フラグを追加
)

# 関数: エンコーディングの取得
function Get-FileEncoding {
    param([string]$Path)
    $bytes = [byte[]](Get-Content $Path -Encoding Byte -ReadCount 4 -TotalCount 4)
    
    if ($bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) { return 'utf8' }
    elseif ($bytes[0] -eq 0xff -and $bytes[1] -eq 0xfe) { return 'unicode' }
    elseif ($bytes[0] -eq 0xfe -and $bytes[1] -eq 0xff) { return 'bigendianunicode' }
    elseif ($bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xfe -and $bytes[3] -eq 0xff) { return 'utf32' }
    else { return 'ascii' }
}

# 関数: Excelセーフな文字列に変換
function Convert-ToExcelSafeString {
    param([string]$Value)
    
    # 数値として解釈される可能性のある文字列を処理
    if ($Value -match '^\d+$' -or $Value -match '^\d+\.\d+$') {
        return "`'$Value"  # 数値の前にシングルクォートを追加
    }
    # 特殊文字を含む場合はダブルクォートで囲む
    elseif ($Value -match '[,\s"]') {
        return '"' + $Value.Replace('"', '""') + '"'
    }
    else {
        return $Value
    }
}

try {
    # ファイルの存在確認
    if (-not (Test-Path $InputPath)) {
        throw "入力ファイルが見つかりません: $InputPath"
    }

    # 入力ファイルのエンコーディングを自動検出（指定がない場合）
    if ($InputEncoding -eq 'auto') {
        $InputEncoding = Get-FileEncoding $InputPath
    }

    # データの読み込み
    $content = Get-Content $InputPath -Encoding $InputEncoding
    
    # データが空でないことを確認
    if ($content.Count -eq 0) {
        throw "入力ファイルが空です"
    }

    # 出力データを格納する配列
    $outputData = @()

    # ヘッダー行の処理
    $header = $null
    if (-not $NoHeader) {
        $header = $content[$HeaderRowIndex].Split($InputDelimiter)
        if ($ExcelFormat) {
            $header = $header | ForEach-Object { Convert-ToExcelSafeString $_ }
        }
        $outputData += $header -join $OutputDelimiter
    }

    # データ行の処理
    $startIndex = if ($NoHeader) { 0 } else { $HeaderRowIndex + 1 }
    for ($i = $startIndex; $i -lt $content.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($content[$i])) { continue }
        
        # 引用符で囲まれたフィールドを適切に処理
        $line = $content[$i]
        $fields = [System.Collections.ArrayList]@()
        $currentField = ""
        $inQuotes = $false
        
        for ($j = 0; $j -lt $line.Length; $j++) {
            $char = $line[$j]
            if ($char -eq '"') {
                $inQuotes = -not $inQuotes
            }
            elseif ($char -eq $InputDelimiter -and -not $inQuotes) {
                if ($ExcelFormat) {
                    $fields.Add((Convert-ToExcelSafeString $currentField.Trim('"'))) | Out-Null
                } else {
                    $fields.Add($currentField.Trim('"')) | Out-Null
                }
                $currentField = ""
            }
            else {
                $currentField += $char
            }
        }
        if ($ExcelFormat) {
            $fields.Add((Convert-ToExcelSafeString $currentField.Trim('"'))) | Out-Null
        } else {
            $fields.Add($currentField.Trim('"')) | Out-Null
        }
        
        # 行データの追加
        $outputData += $fields -join $OutputDelimiter
    }

    # ファイルの出力
    $outputData -join $NewLineChar | Out-File -FilePath $OutputPath -Encoding $OutputEncoding -NoNewline

    Write-Output "ファイルの変換が完了しました。`n入力: $InputPath`n出力: $OutputPath"
}
catch {
    Write-Error "エラーが発生しました: $_"
    exit 1
}

--------------------------------------------------------------------------------------------------------------------------

# 基本的な使用方法
.\ConvertTo-Excel.ps1 -InputPath "input.csv" -OutputPath "output.xlsx"

# Excel最適化を有効にした変換
.\ConvertTo-Excel.ps1 -InputPath "input.csv" -OutputPath "output.xlsx" -ExcelFormat

# カスタム区切り文字とエンコーディングの指定
.\ConvertTo-Excel.ps1 -InputPath "input.txt" -OutputPath "output.csv" -InputDelimiter "|" -OutputDelimiter "," -InputEncoding "utf8" -OutputEncoding "utf8BOM"
