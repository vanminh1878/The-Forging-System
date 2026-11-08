import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/member_hit.dart';

class MemberSearchRepositoryImpl implements MemberSearchRepository {
  MemberSearchRepositoryImpl(this.api);

  final ApiClient api;

  /// Only the first page: at the desk the answer is to type more of the name, not to scroll.
  static const int pageSize = 20;

  @override
  Future<MemberSearchResult> search(String query) async {
    final response = await api.get('/members', query: <String, dynamic>{
      if (query.isNotEmpty) 'q': query,
      'page': 1,
      'limit': pageSize,
    });
    return MemberSearchResult(
      items:
          response.dataList.map((e) => _hit(asMap(e))).toList(growable: false),
      total: intOf(response.meta ?? const <String, dynamic>{}, 'total'),
    );
  }

  MemberHit _hit(JsonMap j) => MemberHit(
        id: str(j, 'userId'),
        memberCode: str(j, 'memberCode'),
        fullName: str(j, 'fullName'),
        phone: strOrNull(j, 'phone'),
        avatarUrl: strOrNull(j, 'avatarUrl'),
        status: str(j, 'status', 'ACTIVE'),
        rankName: strOrNull(j, 'rankName'),
        packageName: strOrNull(j, 'packageName'),
        packageEndDate: strOrNull(j, 'packageEndDate'),
      );
}
