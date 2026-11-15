import '../../../../core/utils/json_utils.dart';
import '../../domain/membership_models.dart';
import '../../domain/package_class_option.dart';

int? _intOrNull(JsonMap j, String key) => j[key] == null ? null : intOf(j, key);

/// The `class` object of a renewal request, or null.
RenewalClass? renewalClassFromJson(Object? value) {
  if (value is! Map) return null;
  final j = asMap(value);
  return RenewalClass(
    id: str(j, 'id'),
    name: str(j, 'name'),
    branchName: str(j, 'branchName'),
    weekdays: weekdaysOf(j['weekdays']),
    startTime: str(j, 'startTime'),
  );
}

/// ISO weekdays from a JSON list.
List<int> weekdaysOf(Object? value) => asList(value)
    .whereType<num>()
    .map((d) => d.toInt())
    .toList(growable: false);

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
              classInfo:
                  renewalClassFromJson(asMap(j['pendingRenewal'])['class']),
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
    classInfo: renewalClassFromJson(j['class']),
  );
}

PackageClassOption packageClassFromJson(JsonMap j) => PackageClassOption(
      id: str(j, 'id'),
      name: str(j, 'name'),
      branchName: str(j, 'branchName'),
      coachName: strOrNull(j, 'coachName'),
      weekdays: weekdaysOf(j['weekdays']),
      startTime: str(j, 'startTime'),
      durationMinutes: intOf(j, 'durationMinutes'),
      capacity: _intOrNull(j, 'capacity'),
      seatsLeft: _intOrNull(j, 'seatsLeft'),
      enrolled: boolOf(j, 'enrolled'),
    );
