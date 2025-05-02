// JavaScript バリデーションチェック関数

// メールアドレスのバリデーション
function validateEmail(email) {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);

// 電話番号のバリデーション (例: 03-1234-5678 または 090-1234-5678 の形式)
function validatePhoneNumber(phone) {
  const regex = /^(0\d{1,4}-\d{1,4}-\d{4})$/;
  return regex.test(phone);
}

// パスワード強度バリデーション
// 最低8文字、大文字1つ以上、小文字1つ以上、数字1つ以上
function validatePassword(password) {
  const minLength = password.length >= 8;
  const hasUpperCase = /[A-Z]/.test(password);
  const hasLowerCase = /[a-z]/.test(password);
  const hasNumber = /\d/.test(password);
  
  return minLength && hasUpperCase && hasLowerCase && hasNumber;
}

// クレジットカード番号のバリデーション (Luhnアルゴリズム)
function validateCreditCard(cardNumber) {
  // 数字のみにする
  const digits = cardNumber.replace(/\D/g, '');
  
  if (digits.length < 13 || digits.length > 19) {
    return false;
  }
