import '../../../core/utils/json_utils.dart';
import '../domain/membership_models.dart';
import '../domain/membership_repository.dart';
import '../domain/package_class_option.dart';
import 'dto/membership_dto.dart';
import 'membership_api.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  MembershipRepositoryImpl(this._api);

  final MembershipApi _api;

  @override
  Future<MyMembership> getMyMembership() async =>
      myMembershipFromJson((await _api.mine()).dataMap);

  @override
  Future<List<PackageType>> listPackageTypes() async =>
      (await _api.packageTypes())
          .dataList
          .map((e) => packageTypeFromJson(asMap(e)))
          .toList(growable: false);

  @override
  Future<List<PackageClassOption>> listPackageClasses(
          String packageTypeId) async =>
      (await _api.packageClasses(packageTypeId))
          .dataList
          .map((e) => packageClassFromJson(asMap(e)))
          .toList(growable: false);

  @override
  Future<void> requestRenewal(
      {required String packageTypeId, String? classId, String? note}) async {
    final trimmed = note?.trim();
    await _api.requestRenewal(packageTypeId, classId,
        trimmed == null || trimmed.isEmpty ? null : trimmed);
  }

  @override
  Future<List<RenewalRequest>> listMyRenewalRequests() async =>
      (await _api.myRenewalRequests())
          .dataList
          .map((e) => renewalRequestFromJson(asMap(e)))
          .toList(growable: false);
}
