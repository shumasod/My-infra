<?php

declare(strict_types=1);

final class Validator
{
    // 正規表現（日本向け実用パターン）
    private const PHONE_REGEX       = '/^0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{4}$|^0\d{9,10}$/';
    private const POSTAL_CODE_REGEX = '/^\d{3}-?\d{4}$/';
    private const PASSWORD_REGEX    = '/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/';

    /**
     * メールアドレス検証（filter_var で十分安全）
     */
    public static function email(string $email): bool
    {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    }

    /**
     * 日本国内電話番号（ハイフン・スペースあり/なし、携帯もOK）
     */
    public static function phone(string $phone): bool
    {
        $cleaned = preg_replace('/[^\d]/', '', $phone);
        return preg_match(self::PHONE_REGEX, $phone) === 1
            || preg_match('/^0\d{9,10}$/', $cleaned) === 1;
    }

    /**
     * パスワード強度（8文字以上 + 大文字・小文字・数字）
     */
    public static function password(string $password): bool
    {
        return preg_match(self::PASSWORD_REGEX, $password) === 1;
    }

    /**
     * 日付検証（デフォルト Y-m-d）
     */
    public static function date(string $date, string $format = 'Y-m-d'): bool
    {
        $d = DateTime::createFromFormat('!' . $format, $date);
        return $d !== false && $d->format($format) === $date;
    }

    /**
     * 日本の郵便番号（123-4567 または 1234567）
     */
    public static function postalCode(string $postalCode): bool
    {
        return preg_match(self::POSTAL_CODE_REGEX, trim($postalCode)) === 1;
    }

    /**
     * クレジットカード番号（Luhnアルゴリズム）
     */
    public static function creditCard(string $cardNumber): bool
    {
        $digits = preg_replace('/\D/', '', $cardNumber);

        if (strlen($digits) < 13 || strlen($digits) > 19) {
            return false;
        }

        $sum = 0;
        $reverse = array_reverse(str_split($digits));

        foreach ($reverse as $i => $digit) {
            $value = (int)$digit;
            if ($i % 2 === 1) {
                $value *= 2;
                if ($value > 9) {
                    $value -= 9;
                }
            }
            $sum += $value;
        }

        return $sum % 10 === 0;
    }

    /**
     * ユーザー登録フォームなど一括バリデーション
     *
     * @param array $data
     * @param array $rules カスタムルール指定可能（デフォルトは一般的な登録フォーム用）
     * @return array{is_valid: bool, errors: array<string>}
     */
    public static function form(array $data, array $rules = []): array
    {
        // デフォルトルール（必要に応じて上書き可能）
        $defaultRules = [
            'email'       => ['required' => true,  'rule' => 'email'],
            'phone'       => ['required' => false, 'rule' => 'phone'],
            'password'    => ['required' => true,  'rule' => 'password'],
            'birth_date'  => ['required' => false, 'rule' => 'date'],
            'postal_code' => ['required' => false, 'rule' => 'postalCode'],
        ];

        $rules = array_merge($defaultRules, $rules);
        $errors = [];

        foreach ($rules as $field => $config) {
            $value = $data[$field] ?? null;
            $label = $config['label'] ?? ucwords(str_replace('_', ' ', $field));

            // 必須チェック
            if ($config['required'] && (empty($value) && $value !== '0')) {
                $errors[] = "{$label}は必須です。";
                continue;
            }

            // 値が空なら以降の検証はスキップ
            if (empty($value) && $value !== '0') {
                continue;
            }

            // 個別ルール検証
            $valid = match ($config['rule']) {
                'email'       => self::email($value),
                'phone'       => self::phone($value),
                'password'    => self::password($value),
                'date'        => self::date($value),
                'postalCode'  => self::postalCode($value),
                'creditCard'  => self::creditCard($value),
                default       => true,
            };

            if (!$valid) {
                $errors[] = $config['message'] ?? self::defaultErrorMessage($field, $config['rule']);
            }
        }

        return [
            'is_valid' => empty($errors),
            'errors' => $errors
        ];
    }

    /**
     * デフォルトエラーメッセージ
     */
    private static function defaultErrorMessage(string $field, string $rule): string
    {
        return match ($rule) {
            'email'       => '正しいメールアドレスを入力してください。',
            'phone'       => '電話番号の形式が正しくありません（例: 090-1234-5678 または 09012345678）',
            'password'    => 'パスワードは8文字以上で、大文字・小文字・数字をそれぞれ1文字以上含めてください。',
            'date'        => '日付の形式が正しくありません（例: 2000-01-31）',
            'postalCode'  => '郵便番号は 123-4567 または 1234567 の形式で入力してください。',
            'creditCard'  => 'クレジットカード番号が正しくありません。',
            default       => '入力内容に誤りがあります。',
        };
    }
}

// ──────────────────────────────────────────────────
// 使用例
// ──────────────────────────────────────────────────
if (php_sapi_name() === 'cli' || basename($_SERVER['SCRIPT_FILENAME']) === basename(__FILE__)) {

    $userData = [
        'email'       => 'user@example.co.jp',
        'phone'       => '090-1234-5678',        // OK
        // 'phone'    => '09012345678',          // これもOK
        'password'    => 'MyStrongPass123',
        'birth_date'  => '1995-05-20',
        'postal_code' => '1000001',              // ハイフンなしもOK
    ];

    $result = Validator::form($userData);

    if (!$result['is_valid']) {
        echo "検証エラー:\n";
        foreach ($result['errors'] as $error) {
            echo "・ {$error}\n";
        }
    } else {
        echo "すべての入力が正しいです！\n";
    }

    // クレジットカード単体テスト例
    var_dump(Validator::creditCard('4111-1111-1111-1111')); // bool(true)
}