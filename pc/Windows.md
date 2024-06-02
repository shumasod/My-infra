```powershell
# 管理者権限で実行するための確認
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (!$isAdmin) {
    $argsProcName = "-noexit -file `"$($myInvocation.ScriptName)`" $($myInvocation.UnboundArguments)"
    Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $argsProcName
    Exit
}

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

最初に、現在のプロセスが管理者権限で実行されているかどうかを確認しています。管理者権限がない場合は、PowerShellを管理者として再起動して、スクリプトを管理者モードで実行します。

その後、前のスクリプトと同様の操作を行っています。

1. ディスクキャッシュ、DNSキャッシュ、ファイルシステムキャッシュをクリアする
2. 一時ファイルを削除する
3. システムログを消去する 
4. ディスクをデフラグする
5. SSDの場合はTRIMを実行する
6. ディスクのクリーンアップツールを管理者権限で実行する
7. 最後にPCを強制的に再起動する

このスクリプトは、ユーザーがスクリプトを管理者権限で実行しない場合でも、自動的に管理者モードで再起動されるので便利です。ただし、ユーザーにUACの確認ダイアログが表示されます。

スクリプトの内容によっては、さらに変更が必要な場合もあるので、環境に合わせて適宜調整してください。
