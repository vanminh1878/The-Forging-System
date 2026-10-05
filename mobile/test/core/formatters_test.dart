import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/utils/formatters.dart';

void main() {
  group('formatInt', () {
    test('groups thousands with dots', () {
      expect(formatInt(0), '0');
      expect(formatInt(999), '999');
      expect(formatInt(1000), '1.000');
      expect(formatInt(1234567), '1.234.567');
      expect(formatInt(-45000), '-45.000');
    });
  });

  group('formatSigned', () {
    test('adds a plus sign to positive numbers only', () {
      expect(formatSigned(250), '+250');
      expect(formatSigned(-300), '-300');
      expect(formatSigned(0), '0');
      expect(formatSigned(12500), '+12.500');
    });
  });

  test('formatDecimal1 uses a decimal comma', () {
    expect(formatDecimal1(3.5), '3,5');
    expect(formatDecimal1(2), '2,0');
  });

  group('dates', () {
    test('instants are shown in Vietnam time (UTC+7)', () {
      final instant = DateTime.utc(2026, 10, 5, 17, 30);
      expect(formatDate(instant), '06/10/2026');
      expect(formatDateTime(instant), '06/10/2026 00:30');
    });

    test('calendar dates are never shifted', () {
      expect(formatCalendarDate('2026-10-05'), '05/10/2026');
      expect(formatCalendarDate('not-a-date'), 'not-a-date');
    });

    test('toIsoDate pads month and day', () {
      expect(toIsoDate(DateTime(2026, 3, 7)), '2026-03-07');
    });
  });

  group('formatRelative', () {
    final now = DateTime.utc(2026, 10, 5, 12);

    test('minutes, hours and days', () {
      expect(formatRelative(now.subtract(const Duration(seconds: 20)), now: now), 'Vừa xong');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), '5 phút trước');
      expect(formatRelative(now.subtract(const Duration(hours: 3)), now: now), '3 giờ trước');
      expect(formatRelative(now.subtract(const Duration(days: 2)), now: now), '2 ngày trước');
    });

    test('older than a week falls back to the date', () {
      final old = DateTime.utc(2026, 9, 1, 5);
      expect(formatRelative(old, now: now), '01/09/2026');
    });

    test('future instants read as just now', () {
      expect(formatRelative(now.add(const Duration(minutes: 3)), now: now), 'Vừa xong');
    });
  });
}
