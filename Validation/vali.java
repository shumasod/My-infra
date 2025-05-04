import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

public class DataValidator {
    
    // メールアドレスのバリデーション
    public static boolean validateEmail(String email) {
        String regex = "^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$";
        return Pattern.matches(regex, email);
    }
    
    // 電話番号のバリデーション（日本形式）
    public static boolean validatePhoneNumber(String phone) {
        String regex = "^(0\\d{1,4}-\\d{1,4}-\\d{4})$";
        return Pattern.matches(regex, phone);
    }
    
    // パスワード強度のバリデーション
    public static boolean validatePassword(String password) {
        // 最低8文字
        if (password.length() < 8) {
            return false;
        }
        
        // 大文字を含む
        boolean hasUpperCase = !password.equals(password.toLowerCase());
        
        // 小文字を含む
        boolean hasLowerCase = !password.equals(password.toUpperCase());
        
        // 数字を含む
        boolean hasDigit = password.matches(".*\\d.*");
        
        return hasUpperCase && hasLowerCase && hasDigit;
    }
    
    // 日付のバリデーション
    public static boolean validateDate(String dateStr, String format) {
        try {
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern(format);
            LocalDate.parse(dateStr, formatter);
            return true;
        } catch (DateTimeParseException e) {
            return false;
        }
    }
    
    // 郵便番号のバリデーション（日本形式）
    public static boolean validatePostalCode(String postalCode) {
        String regex = "^\\d{3}-\\d{4}$";
        return Pattern.matches(regex, postalCode);
    }
    
    // クレジットカード番号のバリデーション（Luhnアルゴリズム）
    public static boolean validateCreditCard(String cardNumber) {
        // 数字以外を削除
        String digits = cardNumber.replaceAll("\\D", "");
        
        if (digits.length() < 13 || digits.length() > 19) {
            return false;
        }
        
        // Luhnアルゴリズム
        int sum = 0;
        boolean alternate = false;
        
        for (int i = digits.length() - 1; i >= 0; i--) {
            int n = Integer.parseInt(digits.substring(i, i + 1));
            if (alternate) {
                n *= 2;
                if (n > 9) {
                    n = (n % 10) + 1;
                }
            }
            sum += n;
            alternate = !alternate;
        }
        
        return (sum % 10 == 0);
    }
    
    // フォームバリデーションの例
    public static ValidationResult validateUserForm(UserForm form) {
        List errors = new ArrayList<>();
        
        if (!validateEmail(form.getEmail())) {
            errors.add("有効なメールアドレスを入力してください。");
        }
        
        if (!validatePhoneNumber(form.getPhone())) {
            errors.add("有効な電話番号を入力してください。(例: 03-1234-5678)");
        }
        
        if (!validatePassword(form.getPassword())) {
            errors.add("パスワードは8文字以上で、大文字小文字と数字を含める必要があります。");
        }
        
        if (!validateDate(form.getBirthDate(), "yyyy-MM-dd")) {
            errors.add("有効な生年月日を入力してください。(例: 2000-01-31)");
        }
        
        return new ValidationResult(errors.isEmpty(), errors);
    }
    
    // バリデーション結果を保持するクラス
    public static class ValidationResult {
        private final boolean valid;
        private final List errors;
        
        public ValidationResult(boolean valid, List errors) {
            this.valid = valid;
            this.errors = errors;
        }
        
        public boolean isValid() {
            return valid;
        }
        
        public List getErrors() {
            return errors;
        }
    }
}

