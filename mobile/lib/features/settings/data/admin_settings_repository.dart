import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/admin_setting.dart';

class AdminSettingsRepositoryImpl implements AdminSettingsRepository {
  AdminSettingsRepositoryImpl(this._api);
  final ApiClient _api;
  @override
  Future<List<AdminSetting>> list() async =>
      (await _api.get('/admin/settings')).dataList.map((item) {
        final json = asMap(item);
        return AdminSetting(
            key: str(json, 'key'),
            group: str(json, 'group'),
            type: str(json, 'type'),
            value: json['value'],
            defaultValue: json['defaultValue'],
            description: str(json, 'description'),
            isDefault: boolOf(json, 'isDefault'));
      }).toList(growable: false);
  @override
  Future<void> update(String key, Object value, String reason) =>
      _api.put('/admin/settings/$key',
          body: <String, dynamic>{'value': value, 'reason': reason.trim()});
  @override
  Future<void> rollback(String key, int auditId, String reason) =>
      _api.post('/admin/settings/$key/rollback',
          body: <String, dynamic>{'auditId': auditId, 'reason': reason.trim()});
}
