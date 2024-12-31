# CSV検証・変換スクリプト
param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [string]$InputDelimiter = ',',
    [string]$OutputDelimiter = "`t",
    [string]$InputEncoding = 'utf8',
    [string]$OutputEncoding = 'utf8BOM',
    [switch]$NoHeader,
    [string]$NewLineChar = [Environment]::NewLine,
    [int]$HeaderRowIndex = 0,
    [switch]$ExcelFormat,
    [switch]$StrictValidation
)

# 警告とエラーのカウンター
$script:warningCount = 0
$script:errorCount = 0
$script:fixedCount = 0

# カラーコード定義
$colors = @{
    Error = 'Red'
    Warning = 'Yellow'
    Info = 'Cyan'
    Success = 'Green'
}

# ログ出力関数
function Write-Log {
    param(
        [string]$Message,
        [string]$Type = 'Info'
    )
    
    $color = $colors[$Type]
    Write-Host "[$Type] $Message" -ForegroundColor $color
    
    switch ($Type) {
        'Warning' { $script:warningCount++ }
        'Error' { $script:errorCount++ }
    }
}

# CSVバリデーション関数
function Test-CsvValidity {
    param(
        [string]$Line,
        [int]$LineNumber,
        [int]$ExpectedFields = 0
    )
    
    $issues = @()
    
    # 空行チェック
    if ([string]::IsNullOrWhiteSpace($Line)) {
        $issues += "空行を検出"
        return $issues
    }
    
    # 引用符の数が奇数
    $quoteCount = ($Line.ToCharArray() | Where-Object { $_ -eq '"' } | Measure-Object).Count
    if ($quoteCount % 2 -ne 0) {
        $issues += "引用符の数が不正"
    }
    
    # フィールド数チェック
    $fields = Get-CsvFields $Line
    if ($ExpectedFields -gt 0 -and $fields.Count -ne $ExpectedFields) {
        $issues += "フィールド数が不一致 (期待値: $ExpectedFields, 実際: $($fields.Count))"
    }
    
    # 改行文字チェック
    if ($Line -match "`r" -or $Line -match "`n") {
        $issues += "不正な改行文字を含む"
    }
    
    # 制御文字チェック
    if ($Line -match '[^\x20-\x7E\xA1-\xDF]') {
        $issues += "制御文字または不正な文字を含む"
    }
    
    return $issues
}

# CSV修正関数
function Repair-CsvLine {
    param(
        [string]$Line,
        [int]$LineNumber,
        [int]$ExpectedFields
    )
    
    # 空白の除去
    $Line = $Line.Trim()
    
    # 引用符の修正
    $Line = $Line -replace '"{3,}', '""'
    
    # フィールド数の調整
    $fields = Get-CsvFields $Line
    if ($ExpectedFields -gt 0) {
        while ($fields.Count -lt $ExpectedFields) {
            $fields += ""
        }
        $fields = $fields[0..($ExpectedFields-1)]
    }
    
    # フィールドの整形とエスケープ
    $fields = $fields | ForEach-Object {
        $field = $_.Trim()
        if ($field -match '[,"\r\n]' -or $field -match '^\s|\s$') {
            $field = '"' + ($field -replace '"', '""') + '"'
        }
        $field
    }
    
    return $fields -join $OutputDelimiter
}

# CSVフィールド分割関数
function Get-CsvFields {
    param([string]$Line)
    
    $fields = [System.Collections.ArrayList]@()
    $currentField = ""
    $inQuotes = $false
    
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $char = $Line[$i]
        
        if ($char -eq '"') {
            $inQuotes = -not $inQuotes
        }
        elseif ($char -eq $InputDelimiter -and -not $inQuotes) {
            $fields.Add($currentField.Trim('"')) | Out-Null
            $currentField = ""
        }
        else {
            $currentField += $char
        }
    }
    
    $fields.Add($currentField.Trim('"')) | Out-Null
    return $fields
}

# Excel形式に変換する関数
function Convert-ToExcelFormat {
    param([string]$Value)
    
    if ($Value -match '^\d+$' -or $Value -match '^\d+\.\d+$') {
        return "`'$Value"
    }
    elseif ($Value -match '[,\s"]') {
        return '"' + $Value.Replace('"', '""') + '"'
    }
    return $Value
}

try {
    Write-Log "CSV検証・変換を開始します" -Type 'Info'
    
    # 入力ファイルの確認
    if (-not (Test-Path $InputPath)) {
        throw "入力ファイルが見つかりません: $InputPath"
    }
    
    # データの読み込み
    $content = Get-Content $InputPath -Encoding $InputEncoding
    if ($content.Count -eq 0) {
        throw "入力ファイルが空です"
    }
    
    # 期待されるフィールド数の取得
    $expectedFields = 0
    if (-not $NoHeader) {
        $headerFields = Get-CsvFields $content[$HeaderRowIndex]
        $expectedFields = $headerFields.Count
        Write-Log "ヘッダーから検出したフィールド数: $expectedFields" -Type 'Info'
    }
    
    # 出力データの準備
    $outputData = @()
    
    # ヘッダー処理
    if (-not $NoHeader) {
        $headerLine = $content[$HeaderRowIndex]
        $headerIssues = Test-CsvValidity $headerLine $HeaderRowIndex
        
        if ($headerIssues) {
            Write-Log "ヘッダーの問題を検出: $($headerIssues -join ', ')" -Type 'Warning'
            $headerLine = Repair-CsvLine $headerLine $HeaderRowIndex $expectedFields
            $script:fixedCount++
        }
        
        if ($ExcelFormat) {
            $headerFields = Get-CsvFields $headerLine
            $headerFields = $headerFields | ForEach-Object { Convert-ToExcelFormat $_ }
            $headerLine = $headerFields -join $OutputDelimiter
        }
        
        $outputData += $headerLine
    }
    
    # データ行の処理
    $startIndex = if ($NoHeader) { 0 } else { $HeaderRowIndex + 1 }
    for ($i = $startIndex; $i -lt $content.Count; $i++) {
        $line = $content[$i]
        
        # 空行のスキップ
        if ([string]::IsNullOrWhiteSpace($line)) {
            Write-Log "行 $($i + 1): 空行をスキップ" -Type 'Warning'
            continue
        }
        
        # バリデーション
        $issues = Test-CsvValidity $line ($i + 1) $expectedFields
        if ($issues) {
            Write-Log "行 $($i + 1): $($issues -join ', ')" -Type 'Warning'
            
            if ($StrictValidation) {
                Write-Log "厳密モード: 不正な行をスキップ" -Type 'Error'
                continue
            }
            
            $line = Repair-CsvLine $line ($i + 1) $expectedFields
            $script:fixedCount++
        }
        
        if ($ExcelFormat) {
            $fields = Get-CsvFields $line
            $fields = $fields | ForEach-Object { Convert-ToExcelFormat $_ }
            $line = $fields -join $OutputDelimiter
        }
        
        $outputData += $line
    }
    
    # 結果の出力
    $outputData -join $NewLineChar | Out-File -FilePath $OutputPath -Encoding $OutputEncoding -NoNewline
    
    # 結果サマリー
    Write-Log "処理完了" -Type 'Success'
    Write-Log "警告件数: $script:warningCount" -Type $(if ($warningCount -gt 0) { 'Warning' } else { 'Info' })
    Write-Log "エラー件数: $script:errorCount" -Type $(if ($errorCount -gt 0) { 'Error' } else { 'Info' })
    Write-Log "修正件数: $script:fixedCount" -Type 'Info'
    Write-Log "出力ファイル: $OutputPath" -Type 'Success'
}
catch {
    Write-Log "致命的エラー: $_" -Type 'Error'
    exit 1
}
