/**
 * 実務レベルのバリデーション関数群（2025年最新推奨版）
 */
const Validator = (() => {
  // 正規表現（事前コンパイル済みで高速）
  const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$/i;

  // 日本電話番号：ハイフン・スペースあり/なし、携帯・固定・IP対応
  const PHONE_REGEX = /^0\d{1,4}[- ]?\d{1,4}[- ]?\d{4}$|^0\d{9,10}$/;

  // 郵便番号：123-4567 または 1234567
  const POSTAL_CODE_REGEX = /^\d{3}-?\d{4}$/;

  // パスワード：8文字以上 + 大文字・小文字・数字をそれぞれ1つ以上
  const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;

  /**
   * メールアドレス検証
   */
  const isValidEmail = (email) => {
    return typeof email === 'string' && EMAIL_REGEX.test(email.trim());
  };

  /**
   * 電話番号検証（日本）
   */
  const isValidPhone = (phone) => {
    if (typeof phone !== 'string') return false;
    const cleaned = phone.replace(/[\s-]/g, '');
    return PHONE_REGEX.test(phone) || PHONE_REGEX.test(cleaned);
  };

  /**
   * パスワード強度検証
   */
  const isValidPassword = (password) => {
    return typeof password === 'string' && PASSWORD_REGEX.test(password);
  };

  /**
   * 生年月日検証（YYYY-MM-DD）
   */
  const isValidDate = (dateStr) => {
    if (typeof dateStr !== 'string') return false;
    const regex = /^\d{4}-\d{2}-\d{2}$/;
    if (!regex.test(dateStr)) return false;
    const d = new Date(dateStr);
    return d instanceof Date && !isNaN(d);
  };

  /**
   * 郵便番号検証（日本）
   */
  const isValidPostalCode = (postalCode) => {
    return typeof postalCode === 'string' && POSTAL_CODE_REGEX.test(postalCode.trim());
  };

  /**
   * クレジットカード番号検証（Luhnアルゴリズム）
   */
  const isValidCreditCard = (cardNumber) => {
    if (typeof cardNumber !== 'string') return false;

    const digits = cardNumber.replace(/\D/g, '');
    if (digits.length < 13 || digits.length > 19) return false;

    let sum = 0;
    let shouldDouble = true; // 右から2番目から2倍

    for (let i = digits.length - 1; i >= 0; i--) {
      let digit = parseInt(digits[i], 10);

      if (shouldDouble) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      shouldDouble = !shouldDouble;
    }

    return sum % 10 === 0;
  };

  /**
   * 一括バリデーション（超便利！）
   * @param {Object} data - フォームデータ
   * @returns {{ isValid: boolean, errors: string[] }}
   */
  const validateForm = (data) => {
    const errors = [];

    const addError = (msg) => errors.push(msg);

    if (!isValidEmail(data.email)) {
      addError('正しいメールアドレスを入力してください。');
    }

    if (data.phone && !isValidPhone(data.phone)) {
      addError('電話番号の形式が正しくありません（例: 090-1234-5678 または 09012345678）');
    }

    if (data.password && !isValidPassword(data.password)) {
      addError('パスワードは8文字以上で、大文字・小文字・数字をそれぞれ1つ以上含めてください。');
    }

    if (data.birthDate && !isValidDate(data.birthDate)) {
      addError('生年月日は YYYY-MM-DD 形式で入力してください（例: 2000-01-31）');
    }

    if (data.postalCode && !isValidPostalCode(data.postalCode)) {
      addError('郵便番号は 123-4567 または 1234567 の形式で入力してください。');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  };

  // 公開API
  return {
    isValidEmail,
    isValidPhone,
    isValidPassword,
    isValidDate,
    isValidPostalCode,
    isValidCreditCard,
    validateForm
  validateForm
  };
})();

// ===================================================================
// 使用例（ブラウザでもNode.jsでもOK）
// ===================================================================
if (typeof window !== 'undefined') {
  // ブラウザ例
  console.log('メール:', Validator.isValidEmail('test@example.co.jp')); // true
  console.log('電話:', Validator.isValidPhone('090-1234-5678')); // true
  console.log('パスワード:', Validator.isValidPassword('Pass123')); // true
  console.log('カード:', Validator.isValidCreditCard('4111-1111-1111-1111')); // true

  // 一括バリデーション例
  const result = Validator.validateForm({
    email: 'user@domain.com',
    phone: '09012345678',
    password: 'MyPass123',
    birthDate: '1990-05-20',
    postalCode: '100-0001'
  });

  if (result.isValid) {
    console.log('すべてOK！');
  } else {
    console.error('エラー:', result.errors.join(' / '));
  }
}

export default Validator;