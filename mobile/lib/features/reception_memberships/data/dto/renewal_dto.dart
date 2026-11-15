import '../../../../core/network/api_client.dart';
import '../../../../core/utils/json_utils.dart';
import '../../../membership/data/dto/membership_dto.dart';
import '../../domain/renewal_models.dart';

RenewalRequest renewalFromJson(JsonMap j) {
  final member = asMap(j['member']);
  final wanted = asMap(j['desiredPackage']);
  final current = asMap(j['currentMembership']);
  return RenewalRequest(
    id: str(j, 'id'),
    status: str(j, 'status', 'PENDING'),
    memberId: str(member, 'id'),
    memberName: str(member, 'fullName'),
    memberPhone: strOrNull(member, 'phone'),
    memberCode: str(member, 'memberCode'),
    packageName: str(wanted, 'name'),
    packageTypeId: str(wanted, 'id'),
    classInfo: renewalClassFromJson(j['class']),
    priceVnd: wanted['priceVnd'] == null ? null : intOf(wanted, 'priceVnd'),
    note: strOrNull(j, 'note'),
    reason: strOrNull(j, 'reason'),
    createdAt: dateOrNull(j, 'createdAt'),
    currentPackageName: strOrNull(current, 'packageName'),
    currentEndDate: strOrNull(current, 'endDate'),
  );
}

RenewalPage renewalPageFromEnvelope(ApiEnvelope res) {
  final meta = PageMeta.fromJson(res.meta);
  return RenewalPage(
    items: res.dataList
        .map((e) => renewalFromJson(asMap(e)))
        .toList(growable: false),
    page: meta.page,
    hasMore: meta.hasMore,
  );
}
