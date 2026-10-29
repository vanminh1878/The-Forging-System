import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/schedule/domain/schedule_dates.dart';
import 'package:hvp_forging/features/schedule/domain/schedule_models.dart';

void main() {
  test('weekDays runs Monday to Sunday for any day of the week', () {
    for (final d in <DateTime>[
      DateTime.utc(2026, 3, 2),
      DateTime.utc(2026, 3, 4),
      DateTime.utc(2026, 3, 8)
    ]) {
      final days = weekDays(d);
      expect(isoDay(days.first), '2026-03-02');
      expect(isoDay(days.last), '2026-03-08');
      expect(days, hasLength(7));
    }
  });

  test('week range label and week shifting cross month boundaries', () {
    expect(weekRangeLabel(DateTime.utc(2026, 3, 4)), '02/03 – 08/03');
    expect(weekRangeLabel(shiftWeeks(DateTime.utc(2026, 3, 4), 1)),
        '09/03 – 15/03');
    expect(weekRangeLabel(shiftWeeks(DateTime.utc(2026, 3, 4), -1)),
        '23/02 – 01/03');
  });

  test('weekday labels', () {
    expect(<String>[for (var i = 1; i <= 7; i++) weekdayShort(i)],
        <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']);
    expect(weekdayLong(1), 'Thứ Hai');
    expect(weekdayLong(7), 'Chủ nhật');
  });

  test('formatSessionDay and time range use Vietnam time', () {
    expect(formatSessionDay('2026-03-04'), 'Thứ Tư · 04/03/2026');
    expect(formatSessionDay('bad'), 'bad');
    expect(
        formatTimeRange(
            DateTime.utc(2026, 3, 4, 11), DateTime.utc(2026, 3, 4, 12, 30)),
        '18:00–19:30');
  });

  test('parseIsoDay rejects malformed input', () {
    expect(parseIsoDay('2026-03-04'), DateTime.utc(2026, 3, 4));
    expect(parseIsoDay('04/03/2026'), isNull);
    expect(parseIsoDay(null), isNull);
  });

  test('status wire values, labels and parsing', () {
    expect(SessionStatus.parse('CONFIRMED_PASS'), SessionStatus.confirmedPass);
    expect(SessionStatus.parse('???'), SessionStatus.upcoming);
    expect(<String>[
      for (final s in SessionStatus.values) s.label
    ], <String>[
      'Sắp tới',
      'Chờ coach xác nhận',
      'Đạt',
      'Chưa đạt',
      'Vắng mặt',
      'Đã huỷ'
    ]);
    expect(SessionStatus.cancelled.description, 'Buổi tập đã bị huỷ');
    expect(SessionType.parse('PT').label, 'PT 1-1');
  });

  test('displayTitle: exam prefix and type fallback', () {
    expect(
        ScheduleItem(
          sessionId: 'a',
          sessionType: SessionType.sparring,
          isExam: true,
          startsAt: _t,
          endsAt: _t,
          date: '2026-03-04',
          isToday: false,
          branchName: 'x',
          status: SessionStatus.upcoming,
        ).displayTitle,
        '📝 Sparring');
  });
}

final DateTime _t = DateTime.utc(2026);
