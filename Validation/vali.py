import re
import json
from datetime import datetime

class Validator:
    """入力データバリデーションのためのクラス"""
    
    @staticmethod
    def validate_email(email):
        """メールアドレスのバリデーション"""
        pattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$'
        return bool(re.match(pattern, email))
    
    @staticmethod
    def validate_phone_number(phone):
        """電話番号のバリデーション（日本の形式）"""
        pattern = r'^(0\d{1,4}-\d{1,4}-\d{4})$'
        return bool(re.match(pattern, phone))
    
    @staticmethod
    def validate_password(password):
        """パスワード強度のバリデーション"""
        if len(password) < 8:
            return False
        
        # 大文字、小文字、数字の確認
        has_upper = bool(re.search(r'[A-Z]', password))
        has_lower = bool(re.search(r'[a-z]', password))
        has_digit = bool(re.search(r'\d', password))
        
        return has_upper and has_lower and has_digit
    
    @staticmethod
    def validate_date(date_str, format="%Y-%m-%d"):
        """日付のバリデーション"""
        try:
            datetime.strptime(date_str, format)
            return True
        except ValueError:
            return False
    
    @staticmethod
    def validate_postal_code(postal_code):
        """郵便番号のバリデーション（日本の形式: 123-4567）"""
        pattern = r'^\d{3}-\d{4}$'
        return bool(re.match(pattern, postal_code))
    
    @staticmethod
    def validate_credit_card(card_number):
        """クレジットカード番号のバリデーション（Luhnアルゴリズム）"""
        # 数字以外を削除
        digits = re.sub(r'\D', '', card_number)
        
        if len(digits) < 13 or len(digits) > 19:
            return False
        
        # Luhnアルゴリズム
        check_sum = 0
        num_digits = len(digits)
        odd_even = num_digits & 1
        
        for i in range(num_digits):
            digit = int(digits[i])
            
            if ((i & 1) ^ odd_even) == 0:
                digit *= 2
                if digit > 9:
                    digit -= 9
                    
            check_sum += digit
            
        return (check_sum % 10) == 0
    
    @staticmethod
    def validate_json(json_str):
        """JSONの有効性チェック"""
        try:
            json.loads(json_str)
            return True
        except json.JSONDecodeError:
            return False


# 使用例
def validate_user_form(user_data):
    validator = Validator()
    errors = []
    
    if 'email' in user_data and not validator.validate_email(user_data['email']):
        errors.append("メールアドレスの形式が正しくありません")
        
    if 'phone' in user_data and not validator.validate_phone_number(user_data['phone']):
        errors.append("電話番号の形式が正しくありません (例: 03-1234-5678)")
        
    if 'password' in user_data and not validator.validate_password(user_data['password']):
        errors.append("パスワードは8文字以上で、大文字小文字と数字を含める必要があります")
        
    if 'birth_date' in user_data and not validator.validate_date(user_data['birth_date']):
        errors.append("生年月日の形式が正しくありません (例: 2000-01-31)")
    
    return {
        'is_valid': len(errors) == 0,
        'errors': errors
    }
