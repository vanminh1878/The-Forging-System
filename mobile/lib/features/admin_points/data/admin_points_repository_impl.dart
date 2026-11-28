import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../../fighter_record/data/dto/points_dto.dart';
import '../../fighter_record/domain/points_models.dart';
import '../../reception_checkin/domain/member_hit.dart';
import '../domain/admin_points_repository.dart';

class AdminPointsRepositoryImpl implements AdminPointsRepository {
  AdminPointsRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<MemberSearchResult> searchMembers(String query) async {
    final response = await _api.get('/members', query: <String, dynamic>{
      'q': query.trim(),
      'page': 1,
      'limit': 20,
    });
    return MemberSearchResult(
      items: response.dataList.map((item) {
        final json = asMap(item);
        return MemberHit(
          id: str(json, 'userId'),
          memberCode: str(json, 'memberCode'),
          fullName: str(json, 'fullName'),
          status: str(json, 'status', 'ACTIVE'),
          phone: strOrNull(json, 'phone'),
          avatarUrl: strOrNull(json, 'avatarUrl'),
          rankName: strOrNull(json, 'rankName'),
          dpBalance: (json['dpBalance'] as num?)?.toInt(),
          marksBalance: (json['marksBalance'] as num?)?.toInt(),
        );
      }).toList(growable: false),
      total: intOf(response.meta ?? const <String, dynamic>{}, 'total'),
    );
  }

  @override
  Future<PointsPage> ledger(String memberId, {int page = 1}) async =>
      pointsPageFromEnvelope(
        await _api.get('/members/$memberId/points/transactions',
            query: <String, dynamic>{'page': page, 'limit': 50}),
      );

  @override
  Future<MonthlyPointStatus> monthlyStatus(String memberId) async =>
      monthlyStatusFromJson(
          (await _api.get('/members/$memberId/points/monthly')).dataMap);

  @override
  Future<void> adjust(
    String memberId, {
    required int dpDelta,
    required int marksDelta,
    required String reason,
    bool confirmed = false,
  }) =>
      _api.post('/admin/members/$memberId/points/adjust',
          body: <String, dynamic>{
            'dpDelta': dpDelta,
            'marksDelta': marksDelta,
            'reason': reason.trim(),
            if (confirmed) 'confirmed': true,
          });

  @override
  Future<void> reverse(String transactionId, {required String reason}) =>
      _api.post('/admin/points/transactions/$transactionId/reverse',
          body: <String, dynamic>{'reason': reason.trim()});
}
