/// Pure form validation rules (Vietnamese messages). Return null when valid.
abstract final class AuthValidators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Keeps digits only (a leading `+` is dropped): `+84 912 345 678` -> `84912345678`.
  static String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static bool isPhone(String value) {
    final digits = digitsOnly(value);
    return digits.length >= 9 && digits.length <= 15;
  }

  static String? identifier(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Vui lòng nhập email hoặc số điện thoại.';
    if (v.contains('@')) return isEmail(v) ? null : 'Email chưa đúng định dạng.';
    return isPhone(v) ? null : 'Số điện thoại chưa hợp lệ.';
  }

  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Vui lòng nhập mật khẩu.';
    return null;
  }

  static String? fullName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Vui lòng nhập họ tên.';
    if (v.length < 2) return 'Họ tên cần tối thiểu 2 ký tự.';
    return null;
  }

  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Vui lòng nhập số điện thoại.';
    return isPhone(v) ? null : 'Số điện thoại chưa hợp lệ.';
  }

  static String? optionalEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return isEmail(v) ? null : 'Email chưa đúng định dạng.';
  }

  /// At least [minLength] characters with letters and digits (mirrors the backend rule).
  static String? newPassword(String? value, {int minLength = 6}) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (v.length < minLength) return 'Mật khẩu cần tối thiểu $minLength ký tự.';
    final hasLetter = RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(v);
    final hasDigit = RegExp(r'[0-9]').hasMatch(v);
    if (!hasLetter || !hasDigit) return 'Mật khẩu cần gồm cả chữ và số.';
    return null;
  }

  static String? confirmPassword(String? password, String? confirm) {
    if ((confirm ?? '').isEmpty) return 'Vui lòng nhập lại mật khẩu.';
    if (password != confirm) return 'Mật khẩu xác nhận không khớp.';
    return null;
  }

  static String? pin(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Vui lòng nhập mã PIN.';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(v)) return 'Mã PIN gồm đúng 6 chữ số.';
    return null;
  }
}
