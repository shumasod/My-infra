import requests
import pandas as pd

def create_saas_account(username, email, password):
    saas_api_url = "https://api.saas-provider.com/create-account"

    # 仮のデータ。実際のAPI仕様に基づいて変更が必要です。
    data = {
        "username": username,
        "email": email,
        "password": password
    }

    try:
        # POSTリクエストを送信
        response = requests.post(saas_api_url, json=data)

        # ステータスコードが200番台であれば成功
        if response.status_code // 100 == 2:
            print(f"アカウントが作成されました: {username}")
            return response.json()  # 作成されたアカウントの情報を返す
        else:
            print(f"エラー: {response.status_code}, {response.text}")
            return None

    except Exception as e:
        print(f"エラー: {str(e)}")
        return None

def save_to_csv(accounts, csv_filename):
    df = pd.DataFrame(accounts)
    df.to_csv(csv_filename, index=False)
    print(f"データを {csv_filename} に保存しました。")

# 例: 複数アカウント作成とCSV保存の呼び出し
num_accounts = 5  # 作成するアカウントの数を指定

accounts_list = []

for i in range(num_accounts):
    result = create_saas_account(f"user{i}", f"user{i}@example.com", f"password{i}")
    if result:
        accounts_list.append(result)

# CSVに保存
save_to_csv(accounts_list, "saas_accounts.csv")
