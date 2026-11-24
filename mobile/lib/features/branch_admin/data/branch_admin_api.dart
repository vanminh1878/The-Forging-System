import '../../../core/network/api_client.dart';

/// Raw endpoint calls.
class BranchAdminApi {
  BranchAdminApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> branches() =>
      _api.get('/branches', query: <String, dynamic>{'includeInactive': true});

  Future<ApiEnvelope> create(Map<String, dynamic> body) =>
      _api.post('/admin/branches', body: body);

  Future<ApiEnvelope> update(String id, Map<String, dynamic> body) =>
      _api.patch('/admin/branches/$id', body: body);

  Future<ApiEnvelope> setStatus(String id, Map<String, dynamic> body) =>
      _api.post('/admin/branches/$id/status', body: body);
}
