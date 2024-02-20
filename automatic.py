import requests

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
            print("アカウントが作成されました。")
        else:
            print(f"エラー: {response.status_code}, {response.text}")

    except Exception as e:
        print(f"エラー: {str(e)}")

# 例: アカウント作成の呼び出し
create_saas_account("user123", "user123@example.com", "password123")
