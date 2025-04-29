# ハッキングしたように見せかけるPowershellスクリプト 

# ランダムな文字列を生成する関数
function Get-RandomString($length) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    -join ((0..($length - 1)) | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
}

# ランダムな文字列を生成
$randStr = Get-RandomString -length 100

# ランダムなファイル名を生成 
$randFile = [System.IO.Path]::GetTempFileName()

# ランダムなテキストを生成
$randText = Get-RandomString -length 1000

# テキストをファイルに書き込み
[System.IO.File]::WriteAllText($randFile, $randText)

try {
    # ファイルを開く (実際にはメモ帳で開く)
    $process = Start-Process -FilePath "notepad.exe" -ArgumentList $randFile -PassThru
    
    # 少し待機
    Start-Sleep -Seconds 2
    
    # プロセスを閉じる
    if (!$process.HasExited) {
        $process.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 1
        if (!$process.HasExited) {
            $process.Kill()
        }
    }
    
    # メッセージを出力
    Write-Host "ハッキングが完了しました。"
}
catch {
    Write-Host "エラーが発生しました: $_"
}
finally {
    # 一時ファイルを削除
    if (Test-Path $randFile) {
        Remove-Item $randFile -Force
    }
}

# システム情報収集スクリプト
Write-Host "`n# システム情報収集を開始します..."

# 一時ファイル名を生成
$tempFile = [System.IO.Path]::GetTempFileName()

try {
    # システム情報を収集
    $systemInfo = @{
        "コンピューター名" = $env:COMPUTERNAME
        "OSバージョン" = [System.Environment]::OSVersion.VersionString
        "プロセッサ数" = [System.Environment]::ProcessorCount
        "総物理メモリ" = "取得中..." # ここは実際の実行時に計算
        "ユーザー名" = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        "IPアドレス" = "取得中..." # ここは実際の実行時に取得
    }
    
    # 実際のメモリ情報を取得（可能な場合）
    try {
        $memoryInfo = Get-CimInstance Win32_ComputerSystem
        if ($memoryInfo) {
            $systemInfo["総物理メモリ"] = [Math]::Round(($memoryInfo.TotalPhysicalMemory / 1GB), 2).ToString() + " GB"
        }
    }
    catch {
        $systemInfo["総物理メモリ"] = "取得できませんでした"
    }
    
    # 実際のIPアドレス情報を取得（可能な場合）
    try {
        $ipAddresses = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.PrefixOrigin -eq 'Dhcp' }
        if ($ipAddresses) {
            $systemInfo["IPアドレス"] = ($ipAddresses | Select-Object -First 1).IPAddress
        }
    }
    catch {
        $systemInfo["IPアドレス"] = "取得できませんでした"
    }

    # 情報をファイルに書き込む
    $systemInfo.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } | Out-File -FilePath $tempFile

    # ファイルの内容を表示
    Get-Content $tempFile | Write-Host

    # ランダムな処理時間を模倣
    $processingTime = Get-Random -Minimum 2 -Maximum 5
    Start-Sleep -Seconds $processingTime

    Write-Host "`nシステム情報の収集が完了しました。処理時間: $processingTime 秒"
}
catch {
    Write-Host "エラーが発生しました: $_"
}
finally {
    # 一時ファイルを削除
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
}