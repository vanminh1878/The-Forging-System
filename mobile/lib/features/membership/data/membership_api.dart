import '../../../core/network/api_client.dart';

class MembershipApi {
  MembershipApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> mine() => _api.get('/me/membership');

  Future<ApiEnvelope> packageTypes() => _api.get('/package-types');

  Future<ApiEnvelope> packageClasses(String packageTypeId) =>
      _api.get('/package-types/$packageTypeId/classes');

  Future<ApiEnvelope> requestRenewal(
          String packageTypeId, String? classId, String? note) =>
      _api.post('/me/renewal-requests', body: <String, dynamic>{
        'packageTypeId': packageTypeId,
        if (classId != null) 'classId': classId,
        if (note != null) 'note': note,
      });

  Future<ApiEnvelope> myRenewalRequests() =>
      _api.get('/me/renewal-requests', query: <String, dynamic>{'limit': 50});
}
