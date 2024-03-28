import subprocess
import time

# 必要なモジュールのインポート
import netifaces as ni
import iwlib

# 既知のネットワーク一覧を取得
known_networks = ni.interfaces()

# 安全なネットワークのリスト
safe_networks = ["SSID1", "SSID2", "SSID3"]

# 現在接続されているネットワーク名を取得
current_network = ni.current_interface()

# 安全なネットワークに接続されていない場合は接続
if current_network not in safe_networks:
    for network in safe_networks:
        # ネットワークが存在する場合は接続
        if network in known_networks:
            subprocess.run(["iwconfig", current_network, "essid", network])
            time.sleep(5)
            if ni.current_interface() == network:
                break

# NATを設定
subprocess.run(["iptables", "-t", "nat", "-A", "POSTROUTING", "-o", "eth0", "-j", "MASQUERADE"])

# 最適なルーティングを自動的に設定
subprocess.run(["route", "add", "default", "gw", "<ゲートウェイIPアドレス>"])

# 接続順序を変更（例：SSID1を優先順位1に設定）
subprocess.run(["nmcli", "connection", "modify", "SSID1", "connection.priority", "1"])

# 現在接続しているプロファイルを保存
subprocess.run(["nmcli", "connection", "export", current_network, "path", "/tmp/current_network.xml"])

# ログファイルに出力
with open("/tmp/wifilog.txt", "a") as f:
    f.write("接続処理が完了しました。")
