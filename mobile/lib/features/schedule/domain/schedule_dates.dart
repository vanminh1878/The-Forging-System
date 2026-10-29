/// Pure date helpers for the schedule. All "days" are date-only UTC values, so
/// arithmetic never drifts with the device timezone or DST.
library;

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
const List<String> _weekdayLong = <String>[
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

/// Drops the time part (keeps the wall-clock y/m/d, flagged UTC).
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// `YYYY-MM-DD` of [d].
String isoDay(DateTime d) => toIsoDate(dateOnly(d));

/// Parses `YYYY-MM-DD`; null when malformed.
DateTime? parseIsoDay(String? s) {
  if (s == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return null;
  final p = s.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

/// `T2`..`CN` for a DateTime.weekday value (1..7).
String weekdayShort(int weekday) => _weekdayShort[(weekday - 1) % 7];

/// `Thứ Hai`..`Chủ nhật`.
String weekdayLong(int weekday) => _weekdayLong[(weekday - 1) % 7];

/// Monday of the week containing [d].
DateTime weekStart(DateTime d) {
  final day = dateOnly(d);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Monday..Sunday of the week containing [d].
List<DateTime> weekDays(DateTime d) {
  final start = weekStart(d);
  return List<DateTime>.generate(7, (i) => start.add(Duration(days: i)));
}

/// `dd/MM`.
String formatDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// `02/03 – 08/03` for the week containing [d].
String weekRangeLabel(DateTime d) {
  final days = weekDays(d);
  return '${formatDayMonth(days.first)} – ${formatDayMonth(days.last)}';
}

/// Same weekday in the next/previous week (any day of the target week works for the API).
DateTime shiftWeeks(DateTime d, int weeks) =>
    dateOnly(d).add(Duration(days: 7 * weeks));

/// `HH:mm` in Vietnam time.
String formatTime(DateTime instant) {
  final v = toVietnamTime(instant);
  return '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
}

/// `18:00–19:30`.
String formatTimeRange(DateTime start, DateTime end) =>
    '${formatTime(start)}–${formatTime(end)}';

/// `Thứ Tư · 04/03/2026` from an API `date`; falls back to the raw value.
String formatSessionDay(String isoDate) {
  final d = parseIsoDay(isoDate);
  if (d == null) return isoDate;
  return '${weekdayLong(d.weekday)} · ${formatCalendarDate(isoDate)}';
}
