# 必要なモジュールのインポート
Import-Module NetAdapter

# 既知のネットワーク一覧を取得
$knownNetworks = Get-NetAdapter -IncludeHidden | Where-Object {$_.OperationalStatus -eq "Up"}

# 安全なネットワークのリスト
$safeNetworks = @("SSID1", "SSID2", "SSID3")

# 現在接続されているネットワーク名を取得
$currentNetwork = Get-NetConnection -Name * | Select-Object -Property Name

# 安全なネットワークに接続されていない場合は接続
if ($currentNetwork.Name -notin $safeNetworks) {
    foreach ($network in $safeNetworks) {
        # ネットワークが存在する場合は接続
        if ($knownNetworks | Where-Object {$_.Name -eq $network}) {
            Connect-NetConnection -Name $network
            break
        }
    }
}

# 接続状況を確認
Get-NetConnection

# 接続順序を変更（例：SSID1を優先順位1に設定）
Set-NetAdapter -Name "SSID1" -InterfaceIndex 1 -Priority 1

# 現在接続しているプロファイルを保存
Export-NetAdapter -Name $currentNetwork.Name

# ログファイルに出力
Write-Log "接続処理が完了しました。" -FilePath "C:\temp\wifilog.txt"
