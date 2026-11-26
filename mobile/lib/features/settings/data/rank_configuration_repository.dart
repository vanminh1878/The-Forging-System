import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/rank_configuration.dart';

class RankConfigurationRepository {
  RankConfigurationRepository(this._api);
  final ApiClient _api;
  Future<List<RankConfiguration>> list() async =>
      (await _api.get('/ranks')).dataList.map((item) {
        final j = asMap(item);
        return RankConfiguration(
            id: str(j, 'id'),
            code: str(j, 'code'),
            name: strOrNull(j, 'nameVi') ?? str(j, 'nameEn'),
            minActiveMonths: intOf(j, 'minActiveMonths'),
            requiresTrial: boolOf(j, 'requiresTrial'),
            approvalRole: strOrNull(j, 'approvalRole'));
      }).toList(growable: false);
  Future<void> update(RankConfiguration rank,
          {required int minActiveMonths,
          required bool requiresTrial,
          required String? approvalRole,
          required String reason}) =>
      _api.patch('/admin/ranks/${rank.id}/configuration',
          body: <String, dynamic>{
            'minActiveMonths': minActiveMonths,
            'requiresTrial': requiresTrial,
            'approvalRole': requiresTrial ? approvalRole : null,
            'reason': reason.trim()
          });
  Future<void> rollback(String rankId, int auditId, String reason) =>
      _api.post('/admin/ranks/$rankId/configuration/rollback',
          body: <String, dynamic>{'auditId': auditId, 'reason': reason.trim()});
}
