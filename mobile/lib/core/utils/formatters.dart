/// Locale helpers without `intl` date data so they work in tests and on web
/// without `initializeDateFormatting`. Display timezone is Asia/Ho_Chi_Minh
/// (UTC+7, no DST).
const Duration vietnamOffset = Duration(hours: 7);

/// `1234567` -> `1.234.567` (Vietnamese grouping).
String formatInt(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return negative ? '-${buffer.toString()}' : buffer.toString();
}

/// `+1.250` / `-300` / `0`.
String formatSigned(int value) {
  if (value > 0) return '+${formatInt(value)}';
  return formatInt(value);
}

/// One decimal with comma: `3.5` -> `3,5`.
String formatDecimal1(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

String _two(int n) => n.toString().padLeft(2, '0');

/// Converts any instant to wall-clock time in Vietnam. The returned value is a
/// plain (UTC-flagged) DateTime whose fields are the Vietnamese local time.
DateTime toVietnamTime(DateTime instant) => instant.toUtc().add(vietnamOffset);

/// `05/10/2026`
String formatDate(DateTime instant) {
  final d = toVietnamTime(instant);
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// `05/10/2026 14:30`
String formatDateTime(DateTime instant) {
  final d = toVietnamTime(instant);
  return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

/// Calendar date (`YYYY-MM-DD`) is shown as is, never shifted by timezone.
String formatCalendarDate(String isoDate) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(isoDate)) return isoDate;
  final parts = isoDate.split('-');
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// Relative label for lists: `Vừa xong`, `5 phút trước`, `2 giờ trước`, `3 ngày trước`, else a date.
String formatRelative(DateTime instant, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toUtc();
  final diff = current.difference(instant.toUtc());
  if (diff.isNegative || diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return formatDate(instant);
}

/// `2026-10-05` for a DateTime (no timezone shift).
String toIsoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
