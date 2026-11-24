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

/// The class a renewal request asks for (`class` of a renewal request).
class RenewalClass {
  const RenewalClass({
    required this.id,
    required this.name,
    required this.branchName,
    required this.weekdays,
    required this.startTime,
  });

  final String id;
  final String name;
  final String branchName;

  /// ISO weekdays, 1 = Monday ... 7 = Sunday.
  final List<int> weekdays;

  /// `HH:mm`.
  final String startTime;
}

/// A renewal request waiting for the front desk.
class PendingRenewal {
  const PendingRenewal({
    required this.packageName,
    required this.createdAt,
    this.classInfo,
  });

  final String packageName;
  final DateTime? createdAt;

  /// Null when the package has no classes.
  final RenewalClass? classInfo;
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

/// A package from `GET /package-types`. Null limits mean unlimited, a null
/// price means the price is not set yet. [classCount] is the number of active
/// classes of the package (0 = no class to choose). [isActive] is only false
/// in the admin list (`includeInactive=true`).
class PackageType {
  const PackageType({
    required this.id,
    required this.name,
    this.code = '',
    this.isTrial = false,
    this.durationDays,
    this.totalSessions,
    this.sessionsPerWeek,
    this.priceVnd,
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
    this.classCount = 0,
  });

  final String id;
  final String name;
  final String code;
  final bool isTrial;
  final int? durationDays;
  final int? totalSessions;
  final int? sessionsPerWeek;
  final int? priceVnd;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final int classCount;

  bool get hasClasses => classCount > 0;
}

enum RenewalStatus {
  pending('PENDING', 'Chờ xử lý'),
  completed('COMPLETED', 'Đã gia hạn'),
  cancelled('CANCELLED', 'Đã huỷ');

  const RenewalStatus(this.wire, this.label);

  final String wire;
  final String label;

  static RenewalStatus parse(String? value) {
    for (final s in RenewalStatus.values) {
      if (s.wire == value) return s;
    }
    return RenewalStatus.pending;
  }
}

/// One entry of `GET /me/renewal-requests`. [reason] is the cancel reason.
class RenewalRequest {
  const RenewalRequest({
    required this.id,
    required this.status,
    required this.packageName,
    required this.createdAt,
    this.priceVnd,
    this.reason,
    this.classInfo,
  });

  final String id;
  final RenewalStatus status;
  final RenewalClass? classInfo;
  final String packageName;
  final int? priceVnd;
  final String? reason;
  final DateTime? createdAt;
}
