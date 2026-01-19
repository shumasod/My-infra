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

$script:warningCount = 0
$script:errorCount = 0
$script:fixedCount = 0

$colors = @{
    Error = 'Red'
    Warning = 'Yellow'
    Info = 'Cyan'
    Success = 'Green'
}

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

function Get-CsvFields {
    param(
        [string]$Line,
        [string]$Delimiter
    )
    $fields = [System.Collections.ArrayList]@()
    $currentField = ""
    $inQuotes = $false

    for ($i = 0; $i -lt $Line.Length; $i++) {
        $char = $Line[$i]
        if ($char -eq '"') {
            if ($i + 1 -lt $Line.Length -and $Line[$i + 1] -eq '"') {
                $currentField += '"'
                $i++
            } else {
                $inQuotes = -not $inQuotes
            }
        }
        elseif ($char -eq $Delimiter -and -not $inQuotes) {
            $fields.Add($currentField) | Out-Null
            $currentField = ""
        }
        else {
            $currentField += $char
        }
    }
    $fields.Add($currentField) | Out-Null
    return $fields
}

function Test-CsvValidity {
    param(
        [string]$Line,
        [int]$LineNumber,
        [int]$ExpectedFields = 0,
        [string]$Delimiter
    )
    $issues = @()

    if ([string]::IsNullOrWhiteSpace($Line)) {
        $issues += "空行を検出"
        return $issues
    }

    $quoteCount = ($Line.ToCharArray() | Where-Object { $_ -eq '"' }).Count
    if ($quoteCount % 2 -ne 0) {
        $issues += "引用符の数が不正"
    }

    $fields = Get-CsvFields -Line $Line -Delimiter $Delimiter
    if ($ExpectedFields -gt 0 -and $fields.Count -ne $ExpectedFields) {
        $issues += "フィールド数が不一致 (期待: $ExpectedFields, 実際: $($fields.Count))"
    }

    if ($Line -match "[\x00-\x08\x0B\x0C\x0E-\x1F]") {
        $issues += "制御文字を含む"
    }

    return $issues
}

function Repair-CsvLine {
    param(
        [string]$Line,
        [int]$LineNumber,
        [int]$ExpectedFields,
        [string]$InputDelimiter,
        [string]$OutputDelimiter
    )
    $fields = Get-CsvFields -Line $Line -Delimiter $InputDelimiter

    while ($fields.Count -lt $ExpectedFields) {
        $fields.Add("") | Out-Null
    }

    $fields = $fields[0..($ExpectedFields - 1)]

    $fields = $fields | ForEach-Object {
        $field = $_.Trim()
        if ($field -match '[,"\r\n]' -or $field -match '^\s|\s$') {
            '"' + ($field -replace '"', '""') + '"'
        } else {
            $field
        }
    }

    return $fields -join $OutputDelimiter
}

function Convert-ToExcelFormat {
    param([string]$Value)
    if ($Value -match '^\d+$' -or $Value -match '^\d+\.\d+$') {
        return "`'$Value"
    } elseif ($Value -match '[,\s"]') {
        return '"' + $Value.Replace('"', '""') + '"'
    }
    return $Value
}

try {
    Write-Log "CSV検証・変換を開始します"

    if (-not (Test-Path $InputPath)) {
        throw "入力ファイルが見つかりません: $InputPath"
    }

    $content = Get-Content $InputPath -Encoding $InputEncoding
    if ($content.Count -eq 0) {
        throw "入力ファイルが空です"
    }

    $expectedFields = 0
    if (-not $NoHeader) {
        $headerFields = Get-CsvFields -Line $content[$HeaderRowIndex] -Delimiter $InputDelimiter
        $expectedFields = $headerFields.Count
        Write-Log "ヘッダーから検出したフィールド数: $expectedFields"
    }

    $outputData = @()

    if (-not $NoHeader) {
        $headerLine = $content[$HeaderRowIndex]
        $headerIssues = Test-CsvValidity $headerLine $HeaderRowIndex $expectedFields $InputDelimiter
        if ($headerIssues) {
            Write-Log "ヘッダーの問題: $($headerIssues -join ', ')" 'Warning'
            $headerLine = Repair-CsvLine $headerLine $HeaderRowIndex $expectedFields $InputDelimiter $OutputDelimiter
            $script:fixedCount++
        }

        if ($ExcelFormat) {
            $headerFields = Get-CsvFields -Line $headerLine -Delimiter $OutputDelimiter
            $headerFields = $headerFields | ForEach-Object { Convert-ToExcelFormat $_ }
            $headerLine = $headerFields -join $OutputDelimiter
        }

        $outputData += $headerLine
    }

    $startIndex = if ($NoHeader) { 0 } else { $HeaderRowIndex + 1 }
    for ($i = $startIndex; $i -lt $content.Count; $i++) {
        $line = $content[$i]
        if ([string]::IsNullOrWhiteSpace($line)) {
            Write-Log "行 $($i + 1): 空行をスキップ" 'Warning'
            continue
        }

        $issues = Test-CsvValidity $line ($i + 1) $expectedFields $InputDelimiter
        if ($issues) {
            Write-Log "行 $($i + 1): $($issues -join ', ')" 'Warning'
            if ($StrictValidation) {
                Write-Log "厳密モード: スキップ" 'Error'
                continue
            }
            $line = Repair-CsvLine $line ($i + 1) $expectedFields $InputDelimiter $OutputDelimiter
            $script:fixedCount++
        }

        if ($ExcelFormat) {
            $fields = Get-CsvFields -Line $line -Delimiter $OutputDelimiter
            $fields = $fields | ForEach-Object { Convert-ToExcelFormat $_ }
            $line = $fields -join $OutputDelimiter
        }

        $outputData += $line
    }

    $outputData -join $NewLineChar | Out-File -FilePath $OutputPath -Encoding $OutputEncoding -NoNewline

    Write-Log "処理完了" 'Success'
    Write-Log "警告件数: $script:warningCount"
    Write-Log "エラー件数: $script:errorCount"
    Write-Log "修正件数: $script:fixedCount"
    Write-Log "出力ファイル: $OutputPath" 'Success'
}
catch {
    Write-Log "致命的エラー: $_" 'Error'
    exit 1
}
