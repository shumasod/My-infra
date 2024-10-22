# ハッキングしたように見せかけるPowershellスクリプト 
# ランダムな文字列を生成
$randStr = [System.Random]::new().NextString(100)
# ランダムなファイル名を生成 
$randFile = [System.IO.Path]::GetRandomFileName()
# ランダムなテキストを生成
$randText = [System.Random]::new().NextString(1000)
# テキストをファイルに書き込み
[System.IO.File]::WriteAllText($randFile, $randText)
# ファイルを開く
$process = Start-Process -FilePath $randFile
# プロセスを待機
$process.WaitForExit()
# メッセージを出力
Write-Host "ハッキングが完了しました。"

# システム情報収集スクリプト

# ランダムな文字列を生成する関数
function Get-RandomString($length) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    -join ((0..($length - 1)) | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
}

# 一時ファイル名を生成
$tempFile = [System.IO.Path]::GetTempFileName()

try {
    # システム情報を収集
    $systemInfo = @{
        "コンピューター名" = $env:COMPUTERNAME
        "OSバージョン" = [System.Environment]::OSVersion.VersionString
        "プロセッサ数" = [System.Environment]::ProcessorCount
        "総物理メモリ" = [Math]::Round(((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB), 2).ToString() + " GB"
        "ユーザー名" = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        "IPアドレス" = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.PrefixOrigin -eq 'Dhcp' }).IPAddress
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
