import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final RegExp _hm = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');

/// "18:30" -> 18:30; null when [text] is not a valid 24-hour time.
TimeOfDay? parseHm(String? text) {
  final m = _hm.firstMatch((text ?? '').trim());
  if (m == null) return null;
  return TimeOfDay(
      hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
}

/// 18:05 -> "18:05".
String formatHm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Minutes since midnight, for comparing two times.
int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// Shown under a time field that does not hold a valid HH:mm.
const String invalidHmMessage = 'Nhập giờ theo dạng HH:mm, ví dụ 18:30.';

/// Validator for a required HH:mm field.
String? validateHm(String? value) =>
    parseHm(value) == null ? invalidHmMessage : null;

/// Lets only digits through and inserts the colon: "1830" becomes "18:30". A pasted "6:30" becomes "06:30".
class HmInputFormatter extends TextInputFormatter {
  const HmInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    String text;
    final colon = raw.indexOf(':');
    if (colon >= 0 && colon != 2) {
      final parts = raw.split(':');
      final h = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
      final mm = parts.skip(1).join().replaceAll(RegExp(r'[^0-9]'), '');
      final digits = (h.length == 1 ? '0$h' : h) + mm;
      text = _insertColon(digits.length > 4 ? digits.substring(0, 4) : digits);
    } else {
      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      text = _insertColon(digits.length > 4 ? digits.substring(0, 4) : digits);
    }
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  static String _insertColon(String d) =>
      d.length > 2 ? '${d.substring(0, 2)}:${d.substring(2)}' : d;
}
