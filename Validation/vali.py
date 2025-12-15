import re
import json
from datetime import datetime
from typing import Dict, List, Any


class Validator:
    """入力データバリデーション用のユーティリティクラス"""

    # メールアドレス（RFC 実用上十分な厳密さ + Unicode対応可）
    EMAIL_REGEX = re.compile(
        r"^(?=.{1,254}$)(?=.{1,64}@)[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+"
        r"(?:\.[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+)*"
        r"@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+"
        r"[a-zA-Z]{2,}$",
        re.IGNORECASE
    )

    # 日本国内電話番号（固定・携帯・IP電話対応、ハイフンあり/なし両方OK）
    PHONE_REGEX = re.compile(
        r"^0\d{1,4}-\d{1,4}-\d{4}$|^0\d{9,10}$"
    )

    # 日本の郵便番号（ハイフンあり/なし両方OK）
    POSTAL_CODE_REGEX = re.compile(r"^\d{3}-?\d{4}$")

    @staticmethod
    def validate_email(email: str) -> bool:
        """メールアドレスのバリデーション（厳密め）"""
        if not email or len(email) > 254:
            return False
        return bool(Validator.EMAIL_REGEX.fullmatch(email))

    @staticmethod
    def validate_phone_number(phone: str) -> bool:
        """日本の電話番号（ハイフンあり/なし対応）"""
        cleaned = re.sub(r"[()\s-]", "", phone)  # 余計な文字除去
        return bool(Validator.PHONE_REGEX.fullmatch(cleaned))

    @staticmethod
    def validate_password(password: str, min_length: int = 8) -> bool:
        """パスワード強度チェック
        - 最小長
        - 大文字・小文字・数字をそれぞれ1文字以上
        """
        if len(password) < min_length:
            return False
        has_upper = re.search(r"[A-Z]", password)
        has_lower = re.search(r"[a-z]", password)
        has_digit = re.search(r"\d", password)
        return has_upper and has_lower and has_digit

    @staticmethod
    def validate_date(date_str: str, fmt: str = "%Y-%m-%d") -> bool:
        """指定フォーマットの日付かチェック"""
        try:
            datetime.strptime(date_str, fmt)
            return True
        except ValueError:
            return False

    @staticmethod
    def validate_postal_code(postal_code: str) -> bool:
        """日本の郵便番号（123-4567 または 1234567）"""
        return bool(Validator.POSTAL_CODE_REGEX.fullmatch(postal_code.strip()))

    @staticmethod
    def validate_credit_card(card_number: str) -> bool:
        """Luhnアルゴリズムによるクレジットカード番号チェック"""
        digits = re.sub(r"\D", "", card_number)  # 数字以外除去
        if not (13 <= len(digits) <= 19):
            return False

        # Luhnアルゴリズム（右から処理）
        total = 0
        reverse_digits = digits[::-1]

        for i, digit in enumerate(reverse_digits):
            d = int(digit)
            if i % 2 == 1:  # 2番目、4番目…（右から2番目から2倍）
                d *= 2
                if d > 9:
                    d -= 9
            total += d

        return total % 10 == 0

    @staticmethod
    def validate_json(json_str: str) -> bool:
        """JSON文字列として有効か"""
        try:
            json.loads(json_str)
            return True
        except json.JSONDecodeError:
            return False


# ──────────────────────────────────────────────────
# 使用例（ユーザー登録フォームのバリデーション）
# ──────────────────────────────────────────────────
def validate_user_form(user_data: Dict[str, Any]) -> Dict[str, Any]:
    errors: List[str] = []

    # メールアドレス
    email = user_data.get("email")
    if email and not Validator.validate_email(email):
        errors.append("正しいメールアドレスを入力してください")

    # 電話番号
    phone = user_data.get("phone")
    if phone and not Validator.validate_phone_number(phone):
        errors.append("電話番号の形式が正しくありません（例: 03-1234-5678 または 09012345678）")

    # パスワード
    password = user_data.get("password")
    if password and not Validator.validate_password(password):
        errors.append("パスワードは8文字以上で、大文字・小文字・数字をそれぞれ1文字以上含めてください")

    # 生年月日
    birth_date = user_data.get("birth_date")
    if birth_date and not Validator.validate_date(birth_date):
        errors.append("生年月日は YYYY-MM-DD 形式で入力してください（例: 1990-05-20）")

    # 郵便番号
    postal_code = user_data.get("postal_code")
    if postal_code and not Validator.validate_postal_code(postal_code):
        errors.append("郵便番号は 123-4567 または 1234567 の形式で入力してください")

    return {
        "is_valid": len(errors) == 0,
        "errors": errors,
    }


# テスト実行例
if __name__ == "__main__":
    test_data = {
        "email": "user@example.co.jp",
        "phone": "090-1234-5678",
        "password": "Passw0rd",
        "birth_date": "2000-01-01",
        "postal_code": "100-0001",
    }
    result = validate_user_form(test_data)
    print(result)