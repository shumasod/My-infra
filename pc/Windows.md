```powershell
# ディスクのクリーンアップ
Clear-BCCache
Clear-DnsClientCache
Clear-FileSystemCache
Clear-Host
Clear-RecycleBin -Force
Clear-VMHostCredentialCache

# 一時ファイルの削除
Remove-Item -Path $env:TEMP\* -Force -Recurse
Remove-Item -Path C:\Windows\Temp\* -Force -Recurse

# システムログの削除
Clear-EventLog -LogName * -Verbose

# デフラグ
Optimize-Volume -DriveLetter C -Defrag -Verbose

# SSDの場合はTRIMを実行
$driveletter = (Get-WmiObject win32_operatingsystem).SystemDrive
$driveletter = $driveletter + ":"
$volume = Get-WmiObject -Query "SELECT * FROM MS_DEFRAG_VOL WHERE DriveLetter='$driveletter'"
$volume.ExpressDefrag()

# ディスクのクリーンアップ
Start-Process -FilePath cleanmgr -ArgumentList "/sagerun:65535" -Verb RunAs -Wait

# 再起動
Restart-Computer -Force
```

このスクリプトでは以下の操作を行います。

1. ディスクキャッシュ、DNSキャッシュ、ファイルシステムキャッシュをクリアする
2. 一時ファイルを削除する
3. システムログを消去する
4. ディスクをデフラグする
5. SSDの場合はTRIMを実行する
6. ディスクのクリーンアップツールを実行する
7. 最後にPCを再起動する

このスクリプトは管理者権限で実行する必要があります。初期化の度合いによっては、このスクリプトに追加や変更を加える必要があるかもしれません。スクリプトの内容を理解し、環境に合わせて適切に変更してください。
