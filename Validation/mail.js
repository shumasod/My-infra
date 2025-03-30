// JavaScript バリデーションチェック関数

// メールアドレスのバリデーション
function validateEmail(email) {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
