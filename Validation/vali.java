import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;
import java.util.regex.Pattern;

public final class DataValidator {

    // 正規表現（コンパイル済みで高速）
    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,]$"
    );

    // 日本電話番号：ハイフン・スペースあり/なし、携帯・固定・IP電話対応
    private static final Pattern PHONE_PATTERN = Pattern.compile(
        "^0\\d{1,4}[-\\s]?\\d{1,4}[-\\s]?\\d{4}$|^0\\d{9,10}$"
    );

    // 郵便番号：123-4567 または 1234567
    private static final Pattern POSTAL_CODE_PATTERN = Pattern.compile(
        "^\\d{3}-?\\d{4}$"
    );

    // パスワード：8文字以上 + 大文字・小文字・数字をそれぞれ1文字以上
    private static final Pattern PASSWORD_PATTERN = Pattern.compile(
        "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
    );

    private DataValidator() {} // インスタンス化防止

    /** メールアドレス検証 */
    public static boolean isValidEmail(String email) {
        return email != null && EMAIL_PATTERN.matcher(email).matches();
    }

    /** 電話番号検証（日本向け） */
    public static boolean isValidPhone(String phone) {
        if (phone == null) return false;
        String cleaned = phone.replaceAll("[\\s-]", "");
        return PHONE_PATTERN.matcher(phone).matches() || 
               PHONE_PATTERN.matcher(cleaned).matches();
    }

    /** パスワード強度検証 */
    public static boolean isValidPassword(String password) {
        return password != null && PASSWORD_PATTERN.matcher(password).matches();
    }

    /** 日付検証（デフォルト yyyy-MM-dd） */
    public static boolean isValidDate(String dateStr) {
        return isValidDate(dateStr, "yyyy-MM-dd");
    }

    public static boolean isValidDate(String dateStr, String pattern) {
        if (dateStr == null) return false;
        try {
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern(pattern);
            LocalDate.parse(dateStr, formatter);
            return true;
        } catch (DateTimeParseException e) {
            return false;
        }
    }

    /** 郵便番号検証（日本） */
    public static boolean isValidPostalCode(String postalCode) {
        return postalCode != null && POSTAL_CODE_PATTERN.matcher(postalCode.trim()).matches();
    }

    /** クレジットカード番号検証（Luhnアルゴリズム） */
    public static boolean isValidCreditCard(String cardNumber) {
        if (cardNumber == null) return false;

        String digits = cardNumber.replaceAll("\\D", "");
        if (digits.length() < 13 || digits.length() > 19) return false;

        int sum = 0;
        boolean shouldDouble = true; // 右から2番目から2倍

        for (int i = digits.length() - 1; i >= 0; i--) {
            int digit = digits.charAt(i) - '0';

            if (shouldDouble) {
                digit *= 2;
                if (digit > 9) digit -= 9;
            }

            sum += digit;
            shouldDouble = !shouldDouble;
        }

        return sum % 10 == 0;
    }

    // ===================================================================
    // 柔軟なフォームバリデーション（ルールベース）
    // ===================================================================

    public record ValidationError(String field, String message) {}

    public record ValidationResult(boolean isValid, List<ValidationError> errors) {
        public static final ValidationResult SUCCESS = new ValidationResult(true, List.of());

        public ValidationResult {
            errors = List.copyOf(errors); // 不変リストに
        }

        public void throwIfInvalid() {
            if (!isValid) {
                throw new IllegalArgumentException("Validation failed: " + errors);
            }
        }
    }

    @FunctionalInterface
    public interface ValidatorRule {
        Optional<String> validate(String value);
    }

    public static ValidationResult validate(Map<String, String> data, Map<String, ValidatorRule> rules) {
        List<ValidationError> errors = new ArrayList<>();

        for (var entry : rules.entrySet()) {
            String field = entry.getKey();
            String value = data.getOrDefault(field, "").trim();
            ValidatorRule rule = entry.getValue();

            if (value.isEmpty()) {
                errors.add(new ValidationError(field, fieldLabel(field) + "は必須です。"));
                continue;
            }

            rule.validate(value).ifPresent(msg ->
                errors.add(new ValidationError(field, msg))
            );
        }

        return errors.isEmpty()
            ? ValidationResult.SUCCESS
            : new ValidationResult(false, errors);
    }

    // 便利なプリセットルール
    public static final Map<String, ValidatorRule> USER_FORM_RULES = Map.of(
        "email",       v -> isValidEmail(v)       ? Optional.empty() : Optional.of("正しいメールアドレスを入力してください。"),
        "phone",       v -> isValidPhone(v)       ? Optional.empty() : Optional.of("電話番号の形式が正しくありません（例: 090-1234-5678 または 09012345678）"),
        "password",    v -> isValidPassword(v)    ? Optional.empty() : Optional.of("パスワードは8文字以上で、大文字・小文字・数字をそれぞれ1文字以上含めてください。"),
        "birth_date",  v -> isValidDate(v)        ? Optional.empty() : Optional.of("生年月日は yyyy-MM-dd 形式で入力してください（例: 2000-01-31）"),
        "postal_code", v -> isValidPostalCode(v)  ? Optional.empty() : Optional.of("郵便番号は 123-4567 または 1234567 の形式で入力してください。")
    );

    private static String fieldLabel(String field) {
        return switch (field) {
            case "email"       -> "メールアドレス";
            case "phone"       -> "電話番号";
            case "password"    -> "パスワード";
            case "birth_date"  -> "生年月日";
            case "postal_code" -> "郵便番号";
            default            -> field;
        };
    }

    // ===================================================================
    // 使用例
    // ===================================================================
    public static void main(String[] args) {
        var validator = new DataValidator();

        Map<String, String> userData = Map.of(
            "email",       "taro@example.co.jp",
            "phone",       "090-1234-5678",      // OK
            // "phone",    "09012345678",        // これもOK
            "password",    "SecurePass123",
            "birth_date",  "1990-05-20",
            "postal_code", "1000001"             // ハイフンなしOK
        );

        ValidationResult result = validator.validate(userData, USER_FORM_RULES);

        if (result.isValid()) {
            System.out.println("すべての入力が正しいです！");
        } else {
            System.out.println("入力エラー:");
            result.errors().forEach(e ->
                System.out.println("・ " + e.field() + ": " + e.message())
            );
        }

        // 単体テスト例
        System.out.println("\nクレジットカードテスト:");
        System.out.println("4111111111111111 → " + isValidCreditCard("4111-1111-1111-1111")); // true
        System.out.println("1234567890123456 → " + isValidCreditCard("1234567890123456")); // false
    }
}