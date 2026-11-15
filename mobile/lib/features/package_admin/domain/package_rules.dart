/// Form validators and labels of the admin package screens (pure).
library;

/// Blank is "not set" (null).
int? parseOptionalInt(String text) => int.tryParse(text.trim());

String? validatePackageCode(String? v) =>
    RegExp(r'^[A-Z0-9_]{1,40}$').hasMatch((v ?? '').trim())
        ? null
        : 'Mã gói gồm chữ HOA, số, gạch dưới (tối đa 40 ký tự).';

String? validatePackageName(String? v) {
  final n = (v ?? '').trim().length;
  return n >= 1 && n <= 120 ? null : 'Nhập tên gói (tối đa 120 ký tự).';
}

/// Blank is valid (not set / unlimited); otherwise an int in [min, max].
String? Function(String?) validateOptionalInt(int min, int max) => (v) {
      final text = (v ?? '').trim();
      if (text.isEmpty) return null;
      final n = int.tryParse(text);
      return n != null && n >= min && n <= max
          ? null
          : 'Nhập số từ $min đến $max hoặc để trống.';
    };

String? validateSortOrder(String? v) {
  final n = int.tryParse((v ?? '').trim());
  return n != null && n >= 0 && n <= 999 ? null : 'Thứ tự từ 0 đến 999.';
}

String? validateDescription(String? v) =>
    (v ?? '').length <= 1000 ? null : 'Tối đa 1000 ký tự.';

/// `2 lớp` / `Chưa có lớp`.
String classCountLabel(int count) => count > 0 ? '$count lớp' : 'Chưa có lớp';
