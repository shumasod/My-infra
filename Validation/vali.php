<?php

class Validator {
    /**
     * メールアドレスのバリデーション
     */
    public static function validateEmail($email) {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    }
    
    /**
     * 電話番号のバリデーション（日本形式）
     */
    public static function validatePhoneNumber($phone) {
        return preg_match('/^(0\d{1,4}-\d{1,4}-\d{4})$/', $phone) === 1;
    }
    
    /**
     * パスワード強度のバリデーション
     */
    public static function validatePassword($password) {
        // 最低8文字
        if (strlen($password) < 8) {
            return false;
        }
        
        // 大文字を含む
        if (!preg_match('/[A-Z]/', $password)) {
            return false;
        }
        
        // 小文字を含む
        if (!preg_match('/[a-z]/', $password)) {
            return false;
        }
        
        // 数字を含む
        if (!preg_match('/\d/', $password)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * 日付のバリデーション
     */
    public static function validateDate($date, $format = 'Y-m-d') {
        $d = DateTime::createFromFormat($format, $date);
        return $d && $d->format($format) === $date;
    }
    
    /**
     * 郵便番号のバリデーション（日本形式）
     */
    public static function validatePostalCode($postalCode) {
        return preg_match('/^\d{3}-\d{4}$/', $postalCode) === 1;
    }
    
    /**
     * クレジットカード番号のバリデーション（Luhnアルゴリズム）
     */
    public static function validateCreditCard($cardNumber) {
        // 数字以外を削除
        $digits = preg_replace('/\D/', '', $cardNumber);
        
        if (strlen($digits) < 13 || strlen($digits) > 19) {
            return false;
        }
        
        // Luhnアルゴリズム
        $sum = 0;
        $length = strlen($digits);
        $parity = $length % 2;
        
        for ($i = 0; $i < $length; $i++) {
            $digit = (int)$digits[$i];
            
            if ($i % 2 === $parity) {
                $digit *= 2;
                
                if ($digit > 9) {
                    $digit -= 9;
                }
            }
            
            $sum += $digit;
        }
        
        return $sum % 10 === 0;
    }
    
    /**
     * フォームのバリデーション
     */
    public static function validateForm($data) {
        $errors = [];
        
        if (isset($data['email']) && !self::validateEmail($data['email'])) {
            $errors[] = '有効なメールアドレスを入力してください。';
        }
        
        if (isset($data['phone']) && !self::validatePhoneNumber($data['phone'])) {
            $errors[] = '有効な電話番号を入力してください。(例: 03-1234-5678)';
        }
        
        if (isset($data['password']) && !self::validatePassword($data['password'])) {
            $errors[] = 'パスワードは8文字以上で、大文字小文字と数字を含める必要があります。';
        }
        
        if (isset($data['birth_date']) && !self::validateDate($data['birth_date'])) {
            $errors[] = '有効な生年月日を入力してください。(例: 2000-01-31)';
        }
        
        return [
            'is_valid' => empty($errors),
            'errors' => $errors
        ];
    }
}

// 使用例
function validateUserData($userData) {
    $result = Validator::validateForm($userData);
    
    if (!$result['is_valid']) {
        foreach ($result['errors'] as $error) {
            echo $error . "";
        }
    } else {
        echo "データの検証に成功しました！";
    }
}
?>
