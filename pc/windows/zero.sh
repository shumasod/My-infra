# 必要なモジュールのインポート
Import-Module PSWindowsUpdate
Import-Module ActiveDirectory

# 設定
$ComputerName = "YOUR_COMPUTER_NAME"
$DomainName = "YOUR_DOMAIN_NAME"
$AdminUsername = "YOUR_ADMIN_USERNAME"
$AdminPassword = "YOUR_ADMIN_PASSWORD"
$SoftwareInstallers = @(
    "C:\path\to\installer1.exe",
    "C:\path\to\installer2.exe"
)
$UserSettingsFile = "C:\path\to\usersettings.ini"
$TPMProvisioning = $true # TPMプロビジョニングを有効にするかどうか

# コンピュータ名を変更
Rename-Computer -NewName $ComputerName

# Windows 11の追加設定
# TPMプロビジョニング
if ($TPMProvisioning) {
    Enable-BitLocker -TPMOnly
}

# ドメインに参加
Join-Domain -Name $DomainName -Credential (New-Object System.Management.Automation.PSCredential($AdminUsername, $AdminPassword))

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

# 再起動
Restart-Computer
