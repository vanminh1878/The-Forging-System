/// Display rules for the package screen (pure, unit-tested).
library;

import '../../../core/utils/formatters.dart';
import '../../class_admin/domain/class_rules.dart';
import 'membership_models.dart';
import 'package_class_option.dart';

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

enum MembershipBannerKind { frozen, noPackage, expiring, ended }

class MembershipBannerData {
  const MembershipBannerData({
    required this.kind,
    required this.title,
    required this.ctaLabel,
    this.bonusLabel,
  });

  final MembershipBannerKind kind;
  final String title;
  final String ctaLabel;

  /// Early-renewal reward chip (expiring only).
  final String? bonusLabel;
}

/// What the status banner says, or null when there is nothing to warn about.
/// The server decides when a package is ending (`renewNotice`), not the app.
/// [showNoPackage] is false on "Gói tập", which already has its own empty state.
MembershipBannerData? membershipBanner(MyMembership m,
    {bool showNoPackage = true}) {
  if (m.memberStatus == MemberStatus.frozen) {
    return const MembershipBannerData(
      kind: MembershipBannerKind.frozen,
      title: 'Tài khoản đang đóng băng — chế độ chỉ xem',
      ctaLabel: 'Đăng ký / gia hạn gói để mở lại',
    );
  }
  switch (m.renewNotice) {
    case RenewNotice.noPackage:
      return showNoPackage
          ? const MembershipBannerData(
              kind: MembershipBannerKind.noPackage,
              title: 'Chào mừng! Bạn chưa có gói tập',
              ctaLabel: 'Đăng ký gói tập',
            )
          : null;
    case RenewNotice.ended:
      return const MembershipBannerData(
        kind: MembershipBannerKind.ended,
        title: 'Gói tập đã kết thúc.',
        ctaLabel: 'ĐĂNG KÝ GÓI MỚI',
      );
    case RenewNotice.endingSoon:
      final cur = m.current;
      final days = cur?.daysRemaining;
      final sessions = cur?.sessionsRemaining;
      final left = days != null
          ? ' — còn $days ngày'
          : (sessions != null ? ' — còn $sessions buổi' : '');
      return MembershipBannerData(
        kind: MembershipBannerKind.expiring,
        title: 'Gói sắp kết thúc$left',
        ctaLabel: 'GIA HẠN NGAY',
        bonusLabel: '+50 Marks',
      );
    case RenewNotice.ok:
      return null;
  }
}

/// "Nút Gia hạn" rule of docs/api/memberships.md: enabled unless the package
/// is fine and not renewable early, or a request is already pending.
bool canRequestRenewal(MyMembership m) =>
    (m.renewNotice != RenewNotice.ok || m.canRenewEarly) &&
    m.pendingRenewal == null;

/// `8.900.000đ`, or a placeholder while the package has no price.
String priceLabel(int? priceVnd) =>
    priceVnd == null ? 'Chưa có giá' : '${formatInt(priceVnd)}đ';

/// `84 ngày · 36 buổi` / `Không giới hạn ngày · Không giới hạn buổi`.
String packageSummary(PackageType p) {
  final days = p.durationDays;
  final sessions = p.totalSessions;
  return '${days == null ? 'Không giới hạn ngày' : '$days ngày'} · '
      '${sessions == null ? 'Không giới hạn buổi' : '$sessions buổi'}';
}

/// `18:30` + 60 -> `19:30` (wraps past midnight).
String endTimeLabel(String startTime, int durationMinutes) {
  final parts = startTime.split(':');
  if (parts.length != 2) return startTime;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return startTime;
  final total = (h * 60 + m + durationMinutes) % 1440;
  return '${(total ~/ 60).toString().padLeft(2, '0')}:'
      '${(total % 60).toString().padLeft(2, '0')}';
}

/// `T2, T4, T6 · 18:30–19:30`; without [durationMinutes] only the start time.
String classScheduleLabel(List<int> weekdays, String startTime,
    [int? durationMinutes]) {
  final days = weekdaysLabel(weekdays);
  final time = durationMinutes == null
      ? startTime
      : '$startTime–${endTimeLabel(startTime, durationMinutes)}';
  return days.isEmpty ? time : '$days · $time';
}

/// `Còn 3 chỗ`, `Hết chỗ`, or `Không giới hạn chỗ` when [seatsLeft] is null.
String seatsLabel(int? seatsLeft) {
  if (seatsLeft == null) return 'Không giới hạn chỗ';
  return seatsLeft <= 0 ? 'Hết chỗ' : 'Còn $seatsLeft chỗ';
}

/// `HVP Quận 1 · HLV Trần Văn B`.
String classPlaceLabel(PackageClassOption c) => <String>[
      c.branchName,
      if (c.coachName != null) 'HLV ${c.coachName}',
    ].where((p) => p.isNotEmpty).join(' · ');

/// `Boxing tối · HVP Quận 1 · T2, T4 · 18:30` for a request's class.
String renewalClassLabel(RenewalClass c) => <String>[
      c.name,
      if (c.branchName.isNotEmpty) c.branchName,
      classScheduleLabel(c.weekdays, c.startTime),
    ].join(' · ');
