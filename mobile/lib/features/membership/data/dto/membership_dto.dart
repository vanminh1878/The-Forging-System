import '../../../../core/utils/json_utils.dart';
import '../../domain/membership_models.dart';

int? _intOrNull(JsonMap j, String key) => j[key] == null ? null : intOf(j, key);

MemberPackage memberPackageFromJson(JsonMap j) {
  final type = asMap(j['packageType']);
  return MemberPackage(
    id: str(j, 'id'),
    name: str(type, 'name'),
    isTrial: boolOf(type, 'isTrial'),
    startDate: strOrNull(j, 'startDate'),
    endDate: strOrNull(j, 'endDate'),
    totalSessions: _intOrNull(j, 'totalSessions'),
    usedSessions: intOf(j, 'usedSessions'),
    sessionsRemaining: _intOrNull(j, 'sessionsRemaining'),
    daysRemaining: _intOrNull(j, 'daysRemaining'),
    endingSoon: boolOf(j, 'endingSoon'),
  );
}

MyMembership myMembershipFromJson(JsonMap j) => MyMembership(
      memberStatus: MemberStatus.parse(strOrNull(j, 'memberStatus')),
      current: j['current'] == null
          ? null
          : memberPackageFromJson(asMap(j['current'])),
      scheduled: j['scheduled'] == null
          ? null
          : memberPackageFromJson(asMap(j['scheduled'])),
      pendingRenewal: j['pendingRenewal'] == null
          ? null
          : PendingRenewal(
              packageName: str(asMap(j['pendingRenewal']), 'packageName'),
              createdAt: dateOrNull(asMap(j['pendingRenewal']), 'createdAt'),
            ),
      renewNotice: RenewNotice.parse(strOrNull(j, 'renewNotice')),
      canRenewEarly: boolOf(j, 'canRenewEarly'),
    );

PackageType packageTypeFromJson(JsonMap j) => PackageType(
      id: str(j, 'id'),
      name: str(j, 'name'),
      code: str(j, 'code'),
      isTrial: boolOf(j, 'isTrial'),
      durationDays: _intOrNull(j, 'durationDays'),
      totalSessions: _intOrNull(j, 'totalSessions'),
      sessionsPerWeek: _intOrNull(j, 'sessionsPerWeek'),
      priceVnd: _intOrNull(j, 'priceVnd'),
      description: strOrNull(j, 'description'),
      isActive: boolOf(j, 'isActive', true),
      sortOrder: intOf(j, 'sortOrder'),
      classCount: intOf(j, 'classCount'),
    );

RenewalRequest renewalRequestFromJson(JsonMap j) {
  final pkg = asMap(j['desiredPackage']);
  return RenewalRequest(
    id: str(j, 'id'),
    status: RenewalStatus.parse(strOrNull(j, 'status')),
    packageName: str(pkg, 'name'),
    priceVnd: _intOrNull(pkg, 'priceVnd'),
    reason: strOrNull(j, 'reason'),
    createdAt: dateOrNull(j, 'createdAt'),
  );
}
