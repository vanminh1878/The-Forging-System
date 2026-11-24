import '../../../core/network/api_client.dart';

class PackageAdminApi {
  PackageAdminApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> list() => _api
      .get('/package-types', query: <String, dynamic>{'includeInactive': true});

  Future<ApiEnvelope> create(Map<String, Object?> body) =>
      _api.post('/admin/package-types', body: body);

  Future<ApiEnvelope> update(String id, Map<String, Object?> body) =>
      _api.patch('/admin/package-types/$id', body: body);
}
