import '../../../core/network/api_client.dart';

/// Raw endpoint calls.
class BranchAdminApi {
  BranchAdminApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> branches() =>
      _api.get('/branches', query: <String, dynamic>{'includeInactive': true});
}
