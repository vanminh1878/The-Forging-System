/// Entities of `GET /me/membership`.
library;

/// Account status of the member.
enum MemberStatus {
  active('ACTIVE', 'Đang hoạt động'),
  frozen('FROZEN', 'Đóng băng'),
  inactive('INACTIVE', 'Ngừng hoạt động');

  const MemberStatus(this.wire, this.label);

  final String wire;
  final String label;

  static MemberStatus parse(String? value) {
    for (final s in MemberStatus.values) {
      if (s.wire == value) return s;
    }
    return MemberStatus.inactive;
  }
}

/// Why the member has (or lacks) a usable package.
enum RenewNotice {
  noPackage('NO_PACKAGE'),
  ended('ENDED'),
  endingSoon('ENDING_SOON'),
  ok('OK');

  const RenewNotice(this.wire);

  final String wire;

  static RenewNotice parse(String? value) {
    for (final n in RenewNotice.values) {
      if (n.wire == value) return n;
    }
    return RenewNotice.ok;
  }
}

/// A member package. `scheduled` packages only carry the static fields.
class MemberPackage {
  const MemberPackage({
    required this.id,
    required this.name,
    required this.isTrial,
    required this.startDate,
    this.endDate,
    this.totalSessions,
    this.usedSessions = 0,
    this.sessionsRemaining,
    this.daysRemaining,
    this.endingSoon = false,
  });

  final String id;
  final String name;
  final bool isTrial;

  /// Calendar dates, `YYYY-MM-DD`. A null [endDate] means no expiry.
  final String? startDate;
  final String? endDate;

  /// Null means unlimited sessions.
  final int? totalSessions;
  final int usedSessions;
  final int? sessionsRemaining;

  /// Null means no expiry; 0 is the last day.
  final int? daysRemaining;
  final bool endingSoon;
}

/// A renewal request waiting for the front desk.
class PendingRenewal {
  const PendingRenewal({required this.packageName, required this.createdAt});

  final String packageName;
  final DateTime? createdAt;
}

class MyMembership {
  const MyMembership({
    required this.memberStatus,
    required this.renewNotice,
    this.current,
    this.scheduled,
    this.pendingRenewal,
    this.canRenewEarly = false,
  });

  final MemberStatus memberStatus;
  final MemberPackage? current;
  final MemberPackage? scheduled;
  final PendingRenewal? pendingRenewal;
  final RenewNotice renewNotice;
  final bool canRenewEarly;
}
