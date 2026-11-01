/// Display rules for the package screen (pure, unit-tested).
library;

import '../../../core/utils/formatters.dart';
import 'membership_models.dart';

/// `30/36 buổi đã dùng · còn 6` or `12 buổi đã tập · Không giới hạn`.
String sessionsLabel(MemberPackage p) {
  final total = p.totalSessions;
  if (total == null) return '${p.usedSessions} buổi đã tập · Không giới hạn';
  final remaining =
      p.sessionsRemaining ?? (total - p.usedSessions).clamp(0, total);
  return '${p.usedSessions}/$total buổi đã dùng · còn $remaining';
}

/// `01/09/2026 → 01/11/2026` or `01/09/2026 → không thời hạn`.
String validityLabel(MemberPackage p) {
  final start = p.startDate == null ? '' : formatCalendarDate(p.startDate!);
  final end =
      p.endDate == null ? 'không thời hạn' : formatCalendarDate(p.endDate!);
  return '$start → $end';
}

/// `còn 7 ngày`, `Hôm nay là ngày cuối`, or null when there is no expiry.
String? daysRemainingLabel(int? days) {
  if (days == null) return null;
  return days == 0 ? 'Hôm nay là ngày cuối' : 'còn $days ngày';
}

/// Share of sessions used, 0..1. Null for unlimited packages.
double? sessionsFraction(MemberPackage p) {
  final total = p.totalSessions;
  if (total == null || total <= 0) return null;
  return (p.usedSessions / total).clamp(0.0, 1.0);
}

/// Chip on the current package card.
enum CurrentPackageBadge {
  active('Đang hoạt động'),
  endingSoon('Sắp hết hạn');

  const CurrentPackageBadge(this.label);

  final String label;
}

CurrentPackageBadge currentPackageBadge(MemberPackage p) =>
    p.endingSoon ? CurrentPackageBadge.endingSoon : CurrentPackageBadge.active;
