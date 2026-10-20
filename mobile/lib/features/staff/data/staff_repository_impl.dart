import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/staff_models.dart';
import '../domain/staff_repository.dart';
import 'staff_dto.dart';

class StaffRepositoryImpl implements StaffRepository {
  StaffRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<StaffPage> search(StaffQuery query) async {
    final response = await _api.get('/admin/staff', query: <String, dynamic>{
      'page': query.page,
      'limit': query.limit,
      if (query.q.trim().isNotEmpty) 'q': query.q.trim(),
      if (query.role != null) 'role': query.role!.wire,
      if (query.status != null) 'status': query.status!.wire,
      if (query.branchId != null) 'branchId': query.branchId,
    });
    final meta = PageMeta.fromJson(response.meta, fallbackLimit: query.limit);
    return StaffPage(
        items: response.dataList
            .map((item) => staffMemberFromJson(asMap(item)))
            .toList(growable: false),
        page: meta.page,
        total: meta.total,
        totalPages: meta.totalPages);
  }

  @override
  Future<List<StaffBranch>> branches() async {
    try {
      final response = await _api.get('/branches');
      return response.dataList.map((item) {
        final json = asMap(item);
        return StaffBranch(str(json, 'id'), str(json, 'name'));
      }).toList(growable: false);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
    }
    // BR-01 may not be deployed yet. Derive real branch choices from the full
    // unfiltered staff directory, not just its first page or hard-coded seeds.
    final branches = <String, StaffBranch>{};
    var page = 1;
    while (true) {
      final result = await search(StaffQuery(page: page, limit: 100));
      for (final member in result.items) {
        if (member.branchId != null) {
          branches[member.branchId!] = StaffBranch(
              member.branchId!, member.branchName ?? 'Chi nhánh chưa đặt tên');
        }
      }
      if (!result.hasMore || result.items.isEmpty) break;
      page++;
    }
    return branches.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }
}
