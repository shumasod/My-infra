# メモリデータを保存するディレクトリを設定
$memo_dir = "$env:USERPROFILE\memory_data"
New-Item -ItemType Directory -Force -Path $memo_dir | Out-Null

# 現在の日付を取得
$today = Get-Date -Format "yyyy-MM-dd"
$file = "$memo_dir\$today.txt"

# タスクマネージャーからメモリデータを記録する関数
function Get-MemoryData {
    $available_mem = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB
    $available_mem = [math]::Round($available_mem)
    Add-Content -Path $file -Value $available_mem
}

# 平均メモリ使用量を計算する関数
function Calculate-Average {
    $data = Get-Content $file
    $total = 0
    $count = 0
    foreach ($line in $data) {
        $total += [int]$line
        $count++
    }
    $average = $total / $count
    Write-Host "Average memory usage (MB): $([math]::Round($average))"
}

# メインのループ処理
try {
    while ($true) {
        Get-MemoryData
        Start-Sleep -Seconds 60
    }
}
finally {
    # スクリプトが終了したときに平均を計算
    Calculate-Average
}
