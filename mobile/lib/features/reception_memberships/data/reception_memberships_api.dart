import '../../../core/network/api_client.dart';

/// Raw endpoint calls; mapping to entities happens in `dto/`.
class ReceptionMembershipsApi {
  ReceptionMembershipsApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> renewals(
          {String? q,
          required String status,
          required int page,
          required int limit}) =>
      _api.get('/renewal-requests', query: <String, dynamic>{
        'status': status,
        'page': page,
        'limit': limit,
        if (q != null && q.isNotEmpty) 'q': q,
      });

  Future<ApiEnvelope> approveRenewal(
          String id, String evidenceUrl, String? classId) =>
      _api.post('/renewal-requests/$id/approve', body: <String, dynamic>{
        'paymentEvidenceUrl': evidenceUrl,
        if (classId != null) 'classId': classId,
      });

  Future<ApiEnvelope> cancelRenewal(String id, String reason) =>
      _api.post('/renewal-requests/$id/cancel',
          body: <String, dynamic>{'reason': reason});

  Future<ApiEnvelope> cancelMembership(String id, String reason) =>
      _api.post('/memberships/$id/cancel',
          body: <String, dynamic>{'reason': reason});

  Future<ApiEnvelope> member(String memberId) => _api.get('/members/$memberId');

  Future<ApiEnvelope> memberMembership(String memberId) =>
      _api.get('/members/$memberId/membership');

  Future<ApiEnvelope> packageTypes() => _api.get('/package-types');

  Future<ApiEnvelope> activateMembership(String memberId, String packageTypeId,
          String evidenceUrl, String? classId) =>
      _api.post('/members/$memberId/memberships', body: <String, dynamic>{
        'packageTypeId': packageTypeId,
        if (classId != null) 'classId': classId,
        'paymentEvidenceUrl': evidenceUrl
      });

  Future<ApiEnvelope> createMember(String fullName, String phone) =>
      _api.post('/members',
          body: <String, dynamic>{'fullName': fullName, 'phone': phone});

  Future<ApiEnvelope> changeStatus(
          String memberId, String status, String reason) =>
      _api.post('/members/$memberId/status',
          body: <String, dynamic>{'status': status, 'reason': reason});

  Future<ApiEnvelope> duplicates(String memberId) =>
      _api.get('/members/$memberId/duplicates');

  Future<ApiEnvelope> mergeMembers(String keepId, String dropId) =>
      _api.post('/admin/members/merge',
          body: <String, dynamic>{'keepId': keepId, 'dropId': dropId});
}
