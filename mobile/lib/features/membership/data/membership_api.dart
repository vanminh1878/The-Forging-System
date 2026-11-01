import '../../../core/network/api_client.dart';

class MembershipApi {
  MembershipApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> mine() => _api.get('/me/membership');
}
