# 必要なモジュールのインポート
Import-Module PSWindowsUpdate
Import-Module ActiveDirectory

# 設定
$ComputerName = "YOUR_COMPUTER_NAME"
$DomainName = "YOUR_DOMAIN_NAME"
$AdminUsername = "YOUR_ADMIN_USERNAME"
$AdminPassword = "YOUR_ADMIN_PASSWORD" | ConvertTo-SecureString -AsPlainText -Force
$SoftwareInstallers = @(
    "C:\path\to\installer1.exe",
    "C:\path\to\installer2.exe"
)
$UserSettingsFile = "C:\path\to\usersettings.ini"
$TPMProvisioning = $true # TPMプロビジョニングを有効にするかどうか
$TaskbarSettings = @{
    Alignment = "Left"
    ShowSearch = $false
    ShowCortana = $false
    ShowTaskView = $false 
    ShowWidgets = $false
}

# コンピュータ名を変更
Rename-Computer -NewName $ComputerName

# Windows 11の追加設定
# TPMプロビジョニング
if ($TPMProvisioning) {
    Enable-BitLocker -ProtectorType TPM
}

# ドメインに参加
$AdminCredential = New-Object System.Management.Automation.PSCredential($AdminUsername, $AdminPassword)
Add-Computer -DomainName $DomainName -Credential $AdminCredential

# Windows Updateの適用
Install-WindowsUpdate -AcceptAll -IncludeRecommended

# ソフトウェアのインストール
foreach ($Installer in $SoftwareInstallers) {
    Start-Process -FilePath $Installer -Wait
}

# ユーザー設定の適用
if (Test-Path $UserSettingsFile) {
    Copy-Item $UserSettingsFile -Destination "C:\Users\Default\AppData\Roaming"
}

# タスクバーの設定
Set-TaskbarOptions @TaskbarSettings

# 再起動
Restart-Computer