import '../../../core/utils/json_utils.dart';
import '../../membership/data/dto/membership_dto.dart';
import '../../membership/domain/membership_models.dart';
import '../domain/package_admin_repository.dart';
import '../domain/package_models.dart';
import 'package_admin_api.dart';

class PackageAdminRepositoryImpl implements PackageAdminRepository {
  PackageAdminRepositoryImpl(this._api);

  final PackageAdminApi _api;

  @override
  Future<List<PackageType>> list() async => (await _api.list())
      .dataList
      .map((e) => packageTypeFromJson(asMap(e)))
      .toList(growable: false);

  @override
  Future<PackageType> create(PackageDraft draft) async =>
      packageTypeFromJson((await _api.create(draft.toJson())).dataMap);

  @override
  Future<PackageType> update(String id, Map<String, Object?> changes) async =>
      packageTypeFromJson((await _api.update(id, changes)).dataMap);
}
