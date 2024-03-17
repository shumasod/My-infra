# 必要なモジュールのインポート
Import-Module NetAdapter
Import-Module Routing

# 既知のネットワーク一覧を取得
$knownNetworks = Get-NetAdapter -IncludeHidden | Where-Object {$_.OperationalStatus -eq "Up"}

# 安全なネットワークのリスト
$safeNetworks = @("SSID1", "SSID2", "SSID3")

# 現在接続されているネットワーク名を取得
$currentNetwork = Get-NetConnection -Name * | Select-Object -ExpandProperty Name

# 安全なネットワークに接続されていない場合は接続
if ($currentNetwork -notin $safeNetworks) {
    foreach ($network in $safeNetworks) {
        # ネットワークが存在する場合は接続
        if ($knownNetworks | Where-Object {$_.Name -eq $network}) {
            Connect-NetConnection -Name $network
            $currentNetwork = $network
            break
        }
    }
}

# NATを設定
$nat = New-NetNat -Name MyNAT -InternalIPInterfaceAddressPrefix "192.168.0.0/24"

# 最適なルーティングを自動的に設定
New-NetRoute -DestinationPrefix "0.0.0.0/0" -InterfaceAlias $currentNetwork -NextHop "GatewayIPAddress"

# 接続順序を変更（例：SSID1を優先順位1に設定）
Set-NetAdapter -Name $currentNetwork -InterfaceIndex 1 -Priority 1

# 現在接続しているプロファイルを保存
Export-NetAdapter -Name $currentNetwork -Path "C:\temp\$currentNetwork.xml"

# ログファイルに出力
Write-Log "接続処理が完了しました。" -FilePath "C:\temp\wifilog.txt"
