import '../../../core/branch/branch.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/branch_admin_repository.dart';
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
}
