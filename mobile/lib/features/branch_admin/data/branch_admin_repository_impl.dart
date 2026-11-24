import '../../../core/branch/branch.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/branch_admin_repository.dart';
import '../domain/branch_input.dart';
import 'branch_admin_api.dart';

class BranchAdminRepositoryImpl implements BranchAdminRepository {
  BranchAdminRepositoryImpl(this._api);

  final BranchAdminApi _api;

  @override
  Future<List<Branch>> getBranches() async {
    final res = await _api.branches();
    return res.dataList
        .map((e) => Branch.fromJson(asMap(e)))
        .toList(growable: false);
  }

  @override
  Future<Branch> create(BranchInput input) async =>
      Branch.fromJson((await _api.create(_body(input))).dataMap);

  @override
  Future<Branch> update(String branchId, BranchInput input) async =>
      Branch.fromJson((await _api.update(branchId, _body(input))).dataMap);

  @override
  Future<Branch> setActive(String branchId,
          {required bool isActive, required String reason}) async =>
      Branch.fromJson((await _api.setStatus(branchId,
              <String, dynamic>{'isActive': isActive, 'reason': reason}))
          .dataMap);

  /// `code` is left out on create (the server numbers the branch) and on edit.
  Map<String, dynamic> _body(BranchInput i) => <String, dynamic>{
        if (i.code != null && i.code!.trim().isNotEmpty) 'code': i.code!.trim(),
        'name': i.name.trim(),
        'address': _orNull(i.address),
        'openingHours': _orNull(i.openingHours),
        'latitude': i.latitude,
        'longitude': i.longitude,
        'geofenceRadiusM': i.geofenceRadiusM,
      };

  String? _orNull(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
}
