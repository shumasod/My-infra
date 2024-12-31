import os
import time
import hashlib
import logging
import requests
import pandas as pd
from dotenv import load_dotenv

# 環境変数の読み込み
load_dotenv()

# ログの設定
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# SaaS APIのURLを環境変数から取得
SAAS_API_URL = os.getenv('SAAS_API_URL')

def hash_password(password):
    """パスワードをハッシュ化する"""
    return hashlib.sha256(password.encode()).hexdigest()

def create_saas_account(username, email, password):
    """SaaSアカウントを作成する"""
    data = {
        "username": username,
        "email": email,
        "password": hash_password(password)
    }
    try:
        response = requests.post(SAAS_API_URL, json=data)
        response.raise_for_status()
        logging.info(f"アカウントが作成されました: {username}")
        return response.json()
    except requests.exceptions.HTTPError as e:
        logging.error(f"HTTPエラー: {e.response.status_code}, {e.response.text}")
    except requests.exceptions.RequestException as e:
        logging.error(f"リクエストエラー: {str(e)}")
    return None

def save_to_csv(accounts, csv_filename):
    """アカウント情報をCSVファイルに保存する"""
    df = pd.DataFrame(accounts)
    df.to_csv(csv_filename, index=False)
    logging.info(f"データを {csv_filename} に保存しました。")

def main():
    num_accounts = 5  # 作成するアカウントの数
    accounts_list = []
    
    for i in range(num_accounts):
        username = f"user{i}"
        email = f"user{i}@example.com"
        password = f"password{i}"
        
        result = create_saas_account(username, email, password)
        if result:
            accounts_list.append(result)
        
        # 進捗表示
        print(f"進捗: {i+1}/{num_accounts}", end='\r')
        
        # レート制限（3秒間隔）
        time.sleep(3)
    
    print("\n")  # 進捗表示の後に改行
    
    if accounts_list:
        save_to_csv(accounts_list, "saas_accounts.csv")
    else:
        logging.warning("アカウントが作成されませんでした。")

if __name__ == "__main__":
    main()
