import subprocess
import time
import logging
from typing import List, Optional
import netifaces as ni

# ロギングの設定
logging.basicConfig(filename="/tmp/wifilog.txt", level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

# 安全なネットワークのリスト
SAFE_NETWORKS: List[str] = ["SSID1", "SSID2", "SSID3"]
GATEWAY_IP: str = "<ゲートウェイIPアドレス>"  # 実際のIPアドレスに置き換える

def get_known_networks() -> List[str]:
    """既知のネットワーク一覧を取得"""
    return [ni.ifaddresses(iface)[ni.AF_INET][0]['addr'] 
            for iface in ni.interfaces() 
            if ni.AF_INET in ni.ifaddresses(iface)]

def get_current_network() -> Optional[str]:
    """現在接続されているネットワーク名を取得"""
    try:
        return subprocess.check_output(["iwgetid", "-r"], universal_newlines=True).strip()
    except subprocess.CalledProcessError:
        logging.error("現在のネットワーク取得に失敗しました")
        return None

def connect_to_safe_network(known_networks: List[str]) -> None:
    """安全なネットワークに接続"""
    for network in SAFE_NETWORKS:
        if network in known_networks:
            try:
                subprocess.run(["nmcli", "dev", "wifi", "connect", network], check=True)
                time.sleep(5)
                if network == get_current_network():
                    logging.info(f"{network}に接続しました")
                    return
            except subprocess.CalledProcessError:
                logging.error(f"{network}への接続に失敗しました")
    logging.warning("安全なネットワークへの接続に失敗しました")

def setup_nat() -> None:
    """NATを設定"""
    try:
        subprocess.run(["iptables", "-t", "nat", "-A", "POSTROUTING", "-o", "eth0", "-j", "MASQUERADE"], check=True)
        logging.info("NATの設定が完了しました")
    except subprocess.CalledProcessError:
        logging.error("NATの設定に失敗しました")

def setup_routing() -> None:
    """最適なルーティングを設定"""
    try:
        subprocess.run(["route", "add", "default", "gw", GATEWAY_IP], check=True)
        logging.info("ルーティングの設定が完了しました")
    except subprocess.CalledProcessError:
        logging.error("ルーティングの設定に失敗しました")

def set_connection_priority() -> None:
    """接続順序を変更"""
    try:
        subprocess.run(["nmcli", "connection", "modify", "SSID1", "connection.priority", "1"], check=True)
        logging.info("接続優先順位の設定が完了しました")
    except subprocess.CalledProcessError:
        logging.error("接続優先順位の設定に失敗しました")

def export_current_profile(current_network: str) -> None:
    """現在接続しているプロファイルを保存"""
    try:
        subprocess.run(["nmcli", "connection", "export", current_network, "/tmp/current_network.xml"], check=True)
        logging.info("現在のネットワークプロファイルをエクスポートしました")
    except subprocess.CalledProcessError:
        logging.error("ネットワークプロファイルのエクスポートに失敗しました")

def main() -> None:
    known_networks = get_known_networks()
    current_network = get_current_network()

    if current_network not in SAFE_NETWORKS:
        connect_to_safe_network(known_networks)

    setup_nat()
    setup_routing()
    set_connection_priority()

    if current_network:
        export_current_profile(current_network)

    logging.info("全ての処理が完了しました")

if __name__ == "__main__":
    main()
