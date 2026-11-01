import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/domain/membership_rules.dart';

MemberPackage _pkg({
  int? total = 36,
  int used = 30,
  int? remaining = 6,
  String? end = '2026-11-01',
  bool endingSoon = false,
}) =>
    MemberPackage(
      id: 'p',
      name: 'BOOK I',
      isTrial: false,
      startDate: '2026-09-01',
      endDate: end,
      totalSessions: total,
      usedSessions: used,
      sessionsRemaining: remaining,
      endingSoon: endingSoon,
    );

void main() {
  test('sessionsLabel for limited and unlimited packages', () {
    expect(sessionsLabel(_pkg()), '30/36 buổi đã dùng · còn 6');
    expect(sessionsLabel(_pkg(remaining: null)), '30/36 buổi đã dùng · còn 6');
    expect(sessionsLabel(_pkg(total: null, used: 12, remaining: null)),
        '12 buổi đã tập · Không giới hạn');
  });

  test('validityLabel handles open-ended packages', () {
    expect(validityLabel(_pkg()), '01/09/2026 → 01/11/2026');
    expect(validityLabel(_pkg(end: null)), '01/09/2026 → không thời hạn');
  });

  test('daysRemainingLabel', () {
    expect(daysRemainingLabel(null), isNull);
    expect(daysRemainingLabel(0), 'Hôm nay là ngày cuối');
    expect(daysRemainingLabel(7), 'còn 7 ngày');
  });

  test('sessionsFraction is null when unlimited and clamped otherwise', () {
    expect(sessionsFraction(_pkg(total: null)), isNull);
    expect(sessionsFraction(_pkg()), closeTo(30 / 36, 1e-9));
    expect(sessionsFraction(_pkg(used: 50)), 1);
  });

  test('currentPackageBadge follows endingSoon', () {
    expect(currentPackageBadge(_pkg()).label, 'Đang hoạt động');
    expect(currentPackageBadge(_pkg(endingSoon: true)).label, 'Sắp hết hạn');
  });
}
