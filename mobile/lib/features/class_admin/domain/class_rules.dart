import '../../../core/utils/formatters.dart';

const List<String> _weekdayShort = <String>[
  'T2',
  'T3',
  'T4',
  'T5',
  'T6',
  'T7',
  'CN'
];

/// `[1, 3, 5]` -> `T2, T4, T6`.
String weekdaysLabel(List<int> weekdays) {
  final sorted = List<int>.of(weekdays)..sort();
  return sorted
      .where((d) => d >= 1 && d <= 7)
      .map((d) => _weekdayShort[d - 1])
      .join(', ');
}

/// `12/20`, or `12/∞` when the class has no limit.
String enrolmentLabel(int enrolled, int? capacity) =>
    '$enrolled/${capacity ?? '∞'}';

/// Form validators (null = valid). Messages are shown as is.
String? validateClassName(String? v) =>
    (v ?? '').trim().isEmpty ? 'Nhập tên lớp.' : null;

String? validateStartTime(String? v) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch((v ?? '').trim())
        ? null
        : 'Giờ không hợp lệ (HH:mm).';

String? validateDuration(String? v) {
  final n = int.tryParse((v ?? '').trim());
  return n != null && n >= 1 && n <= 1440
      ? null
      : 'Thời lượng từ 1 đến 1440 phút.';
}

/// Only checked when "Không giới hạn sĩ số" is off: a number from 1 to 1000 is required.
String? validateCapacity(String? v) {
  final n = int.tryParse((v ?? '').trim());
  return n != null && n >= 1 && n <= 1000 ? null : 'Sĩ số từ 1 đến 1000.';
}

/// Only a SCHEDULED session that has not started can be cancelled.
bool canCancelSession(String status, DateTime startsAt, DateTime now) =>
    status == 'SCHEDULED' && startsAt.isAfter(now);

String? validateCancelReason(String? v) =>
    (v ?? '').trim().isEmpty ? 'Vui lòng nhập lý do huỷ.' : null;

/// The instant of [day] at `HH:mm` Vietnam wall-clock time (UTC+7). Only the
/// y/m/d of [day] count, whatever its own timezone.
DateTime vietnamInstant(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime.utc(day.year, day.month, day.day, int.parse(parts[0]),
          int.parse(parts[1]))
      .subtract(vietnamOffset);
}

String? validateSessionTitle(String? v) =>
    (v ?? '').trim().isEmpty ? 'Nhập tiêu đề buổi.' : null;

String? validateSessionDuration(String? v) {
  final n = int.tryParse((v ?? '').trim());
  return n != null && n >= 15 && n <= 480
      ? null
      : 'Thời lượng từ 15 đến 480 phút.';
}
