import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/reception_memberships_repository.dart';
import '../domain/renewal_models.dart';
import '../../membership/data/dto/membership_dto.dart';
import '../../reception_checkin/domain/member_hit.dart';
import '../domain/member_models.dart';
import '../../membership/domain/membership_models.dart';
import 'dto/member_dto.dart';
import 'dto/renewal_dto.dart';
import 'reception_memberships_api.dart';

class ReceptionMembershipsRepositoryImpl
    implements ReceptionMembershipsRepository {
  ReceptionMembershipsRepositoryImpl(this._api);

  final ReceptionMembershipsApi _api;

  @override
  Future<RenewalPage> renewals(
          {String? q,
          String status = 'PENDING',
          int page = 1,
          int limit = 20}) async =>
      renewalPageFromEnvelope(
          await _api.renewals(q: q, status: status, page: page, limit: limit));

  @override
  Future<String> approveRenewal(String id,
          {required String evidenceUrl, String? classId}) async =>
      str((await _api.approveRenewal(id, evidenceUrl, classId)).dataMap,
          'message');

  @override
  Future<void> cancelRenewal(String id, {required String reason}) async {
    await _api.cancelRenewal(id, reason);
  }

  @override
  Future<void> cancelMembership(String id, {required String reason}) async {
    await _api.cancelMembership(id, reason);
  }

  @override
  Future<MemberOverview> memberOverview(String memberId) async {
    final results = await Future.wait(<Future<Object>>[
      _api.member(memberId),
      _api.memberMembership(memberId)
    ]);
    return MemberOverview(
      profile: memberProfileFromJson((results[0] as ApiEnvelope).dataMap),
      membership: myMembershipFromJson((results[1] as ApiEnvelope).dataMap),
    );
  }

  @override
  Future<List<PackageType>> packageTypes() async => (await _api.packageTypes())
      .dataList
      .map((e) => packageTypeFromJson(asMap(e)))
      .toList(growable: false);

  @override
  Future<String> activateMembership(String memberId,
          {required String packageTypeId,
          required String evidenceUrl,
          String? classId}) async =>
      str(
          (await _api.activateMembership(
                  memberId, packageTypeId, evidenceUrl, classId))
              .dataMap,
          'message');

  @override
  Future<CreatedMember> createMember(
          {required String fullName, required String phone}) async =>
      createdMemberFromJson((await _api.createMember(fullName, phone)).dataMap);

  @override
  Future<void> changeStatus(String memberId,
      {required String status, required String reason}) async {
    await _api.changeStatus(memberId, status, reason);
  }

  @override
  Future<List<MemberHit>> duplicates(String memberId) async =>
      (await _api.duplicates(memberId))
          .dataList
          .map((e) => duplicateFromJson(asMap(e)))
          .toList(growable: false);

  @override
  Future<void> mergeMembers(
      {required String keepId, required String dropId}) async {
    await _api.mergeMembers(keepId, dropId);
  }
}
