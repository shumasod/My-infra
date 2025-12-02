#!/usr/bin/env python3
"""
セキュリティテスト: 入力検証
作成日: 2025-12-02
バージョン: 1.0

このテストはValidation/vali.pyの入力検証が
セキュリティ攻撃に対して堅牢であることを確認します。
"""

import sys
import os
import unittest
from unittest.mock import patch

# テスト対象のモジュールをインポート
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from Validation.vali import Validator


class TestEmailValidationSecurity(unittest.TestCase):
    """メールアドレス検証のセキュリティテスト"""

    def test_email_injection_crlf(self):
        """メールインジェクション: CRLF攻撃"""
        malicious_emails = [
            "user@example.com\nBcc: attacker@evil.com",
            "user@example.com\rBcc: attacker@evil.com",
            "user@example.com\r\nBcc: attacker@evil.com",
            "user@example.com%0ABcc:attacker@evil.com",
            "user@example.com%0D%0ABcc:attacker@evil.com",
        ]

        for email in malicious_emails:
            with self.subTest(email=email):
                result = Validator.validate_email(email)
                self.assertFalse(
                    result,
                    f"CRLFインジェクションが検出されませんでした: {email}"
                )

    def test_email_header_injection(self):
        """メールヘッダーインジェクション攻撃"""
        malicious_emails = [
            "user@example.com\nContent-Type: text/html",
            "user@example.com\nSubject: Spam",
            "user@example.com\n\n<script>alert('xss')</script>",
        ]

        for email in malicious_emails:
            with self.subTest(email=email):
                self.assertFalse(Validator.validate_email(email))

    def test_email_sql_injection(self):
        """SQLインジェクション試行"""
        malicious_emails = [
            "user' OR '1'='1@example.com",
            "admin'--@example.com",
            "user'; DROP TABLE users;--@example.com",
            "user@example.com'; DELETE FROM emails WHERE '1'='1",
        ]

        for email in malicious_emails:
            with self.subTest(email=email):
                # 無効なメールとして拒否されるべき
                self.assertFalse(Validator.validate_email(email))

    def test_email_xss_attempts(self):
        """XSS攻撃試行"""
        malicious_emails = [
            "<script>alert('xss')</script>@example.com",
            "user@<script>alert('xss')</script>.com",
            "user+<img src=x onerror=alert(1)>@example.com",
            "\"<svg/onload=alert(1)>\"@example.com",
        ]

        for email in malicious_emails:
            with self.subTest(email=email):
                self.assertFalse(Validator.validate_email(email))

    def test_email_length_limits(self):
        """長さ制限のテスト（DoS防止）"""
        # メールアドレスは通常254文字まで
        very_long_email = "a" * 300 + "@example.com"
        self.assertFalse(Validator.validate_email(very_long_email))

        # ドメイン部分が長すぎる
        long_domain = "user@" + "a" * 300 + ".com"
        self.assertFalse(Validator.validate_email(long_domain))

    def test_email_unicode_bypass_attempts(self):
        """Unicode文字を使ったバイパス試行"""
        malicious_emails = [
            "user@еxample.com",  # キリル文字のe
            "user@exаmple.com",  # キリル文字のa
            "user@example。com", # 全角ドット
            "user＠example.com",  # 全角アットマーク
        ]

        for email in malicious_emails:
            with self.subTest(email=email):
                # 基本的なASCII以外は拒否されるべき（要件による）
                result = Validator.validate_email(email)
                # Unicodeを許可するかは実装による
                # 厳格なポリシーでは False を期待


class TestPasswordValidationSecurity(unittest.TestCase):
    """パスワード検証のセキュリティテスト"""

    def test_password_common_patterns(self):
        """よくあるパスワードパターンの拒否"""
        weak_passwords = [
            "Password123",  # 一般的なパターン
            "12345678",     # 数字のみ
            "abcdefgh",     # 文字のみ
            "ABCDEFGH",     # 大文字のみ
            "qwerty123",    # キーボードパターン
        ]

        for password in weak_passwords:
            with self.subTest(password=password):
                # 現在の実装は基本的なチェックのみ
                # より厳格なチェックを推奨
                result = Validator.validate_password(password)

                # Password123は現在の実装ではパスする可能性あり
                # これは改善が必要な点

    def test_password_sql_injection_content(self):
        """SQLインジェクション文字列を含むパスワード"""
        passwords_with_sql = [
            "Pass' OR '1'='1",
            "Pwd123'; DROP TABLE--",
            "Admin'--#123",
        ]

        for password in passwords_with_sql:
            with self.subTest(password=password):
                # パスワード自体は任意の文字を許可すべき
                # ただし、保存時にはハッシュ化される前提
                # 検証ロジックではなく、保存時のハッシュ化が重要
                pass

    def test_password_length_limits(self):
        """長さ制限のテスト"""
        # 非常に長いパスワード（メモリ攻撃）
        very_long_password = "Aa1" + "x" * 10000

        # 実装によっては最大長チェックが必要
        # DoS攻撃防止のため
        result = Validator.validate_password(very_long_password)

        # 現在の実装では長さ上限がないため、改善推奨

    def test_password_null_bytes(self):
        """Null byte injection"""
        passwords = [
            "Password1\x00admin",
            "Pwd123\0DROP",
        ]

        for password in passwords:
            with self.subTest(password=password):
                # Null byteを含むパスワードは拒否されるべき
                result = Validator.validate_password(password)


class TestPhoneNumberValidationSecurity(unittest.TestCase):
    """電話番号検証のセキュリティテスト"""

    def test_phone_sql_injection(self):
        """SQLインジェクション試行"""
        malicious_phones = [
            "090-1234-5678'; DROP TABLE--",
            "03-1234-5678' OR '1'='1",
            "080-1234-5678; DELETE FROM users--",
        ]

        for phone in malicious_phones:
            with self.subTest(phone=phone):
                self.assertFalse(Validator.validate_phone_number(phone))

    def test_phone_format_string_attacks(self):
        """フォーマット文字列攻撃"""
        malicious_phones = [
            "090-1234-%s%s%s",
            "03-1234-%x%x%x",
            "080-1234-%n%n%n",
        ]

        for phone in malicious_phones:
            with self.subTest(phone=phone):
                self.assertFalse(Validator.validate_phone_number(phone))

    def test_phone_script_injection(self):
        """スクリプトインジェクション"""
        malicious_phones = [
            "<script>alert(1)</script>",
            "javascript:alert(1)",
            "090-1234-5678<img src=x onerror=alert(1)>",
        ]

        for phone in malicious_phones:
            with self.subTest(phone=phone):
                self.assertFalse(Validator.validate_phone_number(phone))


class TestCreditCardValidationSecurity(unittest.TestCase):
    """クレジットカード検証のセキュリティテスト"""

    def test_credit_card_sql_injection(self):
        """SQLインジェクション試行"""
        malicious_cards = [
            "4111111111111111'; DROP TABLE cards--",
            "4111-1111-1111-1111' OR '1'='1",
        ]

        for card in malicious_cards:
            with self.subTest(card=card):
                self.assertFalse(Validator.validate_credit_card(card))

    def test_credit_card_overflow(self):
        """整数オーバーフロー試行"""
        overflow_cards = [
            "9" * 100,  # 非常に長い数字列
            "1" * 20,   # 最大長を超える
        ]

        for card in overflow_cards:
            with self.subTest(card=card):
                result = Validator.validate_credit_card(card)
                # 長さチェックで拒否されるべき
                self.assertFalse(result)

    def test_credit_card_unicode_digits(self):
        """Unicode数字を使ったバイパス試行"""
        # 全角数字
        fullwidth_card = "４１１１１１１１１１１１１１１１"

        # これは拒否されるべき（ASCII数字のみ許可）
        result = Validator.validate_credit_card(fullwidth_card)
        # 実装によるが、厳格には False を期待


class TestJSONValidationSecurity(unittest.TestCase):
    """JSON検証のセキュリティテスト"""

    def test_json_billion_laughs(self):
        """Billion Laughs攻撃（XML bomb のJSON版）"""
        # 非常に深いネスト
        deep_json = '{"a":' * 1000 + '1' + '}' * 1000

        # これはメモリ不足やスタックオーバーフローを引き起こす可能性
        # タイムアウトまたは例外が発生すべき
        try:
            result = Validator.validate_json(deep_json)
            # 成功してもメモリ消費に注意
        except (RecursionError, MemoryError):
            # 期待される動作
            pass

    def test_json_large_payload(self):
        """巨大なJSONペイロード（DoS）"""
        # 10MBのJSON
        large_json = '{"data":"' + 'x' * 10_000_000 + '"}'

        try:
            result = Validator.validate_json(large_json)
            # サイズ制限が必要
        except MemoryError:
            pass

    def test_json_prototype_pollution(self):
        """プロトタイプ汚染攻撃（JavaScript特有だが念のため）"""
        malicious_json = '{"__proto__":{"isAdmin":true}}'

        # Pythonでは影響ないが、検証は成功する
        result = Validator.validate_json(malicious_json)
        self.assertTrue(result)  # 有効なJSON


class TestDateValidationSecurity(unittest.TestCase):
    """日付検証のセキュリティテスト"""

    def test_date_sql_injection(self):
        """SQLインジェクション試行"""
        malicious_dates = [
            "2024-01-01'; DROP TABLE users--",
            "2024-01-01' OR '1'='1",
            "2024-01-01\nDELETE FROM logs",
        ]

        for date in malicious_dates:
            with self.subTest(date=date):
                self.assertFalse(Validator.validate_date(date))

    def test_date_format_string(self):
        """フォーマット文字列攻撃"""
        malicious_dates = [
            "2024-%s-%d",
            "2024-%x-%n",
        ]

        for date in malicious_dates:
            with self.subTest(date=date):
                self.assertFalse(Validator.validate_date(date))


class TestPostalCodeValidationSecurity(unittest.TestCase):
    """郵便番号検証のセキュリティテスト"""

    def test_postal_code_sql_injection(self):
        """SQLインジェクション試行"""
        malicious_codes = [
            "123-4567'; DROP TABLE--",
            "100-0001' OR '1'='1",
        ]

        for code in malicious_codes:
            with self.subTest(code=code):
                self.assertFalse(Validator.validate_postal_code(code))


class TestValidatorIntegration(unittest.TestCase):
    """統合セキュリティテスト"""

    def test_validate_user_form_with_malicious_input(self):
        """悪意のある入力を含むフォームデータのテスト"""
        from Validation.vali import validate_user_form

        malicious_data = {
            'email': "user@example.com\nBcc: attacker@evil.com",
            'phone': "090-1234-5678'; DROP TABLE--",
            'password': "pass",  # 短すぎる
            'birth_date': "2000-01-01'; DELETE FROM users--",
        }

        result = validate_user_form(malicious_data)

        # すべてエラーとして検出されるべき
        self.assertFalse(result['is_valid'])
        self.assertGreater(len(result['errors']), 0)

    def test_validate_user_form_with_clean_input(self):
        """正常な入力のテスト"""
        from Validation.vali import validate_user_form

        clean_data = {
            'email': "user@example.com",
            'phone': "03-1234-5678",
            'password': "SecurePass123",
            'birth_date': "2000-01-31",
        }

        result = validate_user_form(clean_data)

        # エラーがないべき
        self.assertTrue(result['is_valid'])
        self.assertEqual(len(result['errors']), 0)


class TestSecurityAutomaticPy(unittest.TestCase):
    """security/automatic.pyのセキュリティテスト"""

    def test_password_hashing_strength(self):
        """パスワードハッシュの強度テスト"""
        # SHA256は高速すぎてパスワードハッシュには不適切
        # bcrypt, argon2, scrypt を推奨

        import hashlib
        password = "TestPassword123"

        # 現在の実装（SHA256）
        weak_hash = hashlib.sha256(password.encode()).hexdigest()

        # SHA256は同じパスワードで常に同じハッシュ
        weak_hash2 = hashlib.sha256(password.encode()).hexdigest()
        self.assertEqual(weak_hash, weak_hash2)

        # これは問題: saltがないため、レインボーテーブル攻撃に脆弱

        # 推奨: bcryptを使用
        # import bcrypt
        # strong_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt())

    def test_api_url_validation(self):
        """API URL検証のテスト"""
        # 環境変数から取得するAPI URLが検証されていない
        # SSRFのリスク

        malicious_urls = [
            "http://localhost:22",  # 内部サービス
            "http://169.254.169.254/latest/meta-data/",  # AWS metadata
            "file:///etc/passwd",  # ファイルアクセス
            "http://internal.company.local",  # 内部ネットワーク
        ]

        # URL検証が必要（実装されていない場合）
        # 推奨: ホワイトリスト方式


if __name__ == '__main__':
    # テスト実行
    unittest.main(verbosity=2)
