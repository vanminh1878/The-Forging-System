import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/challenge_review.dart';

class ChallengeReviewRepositoryImpl implements ChallengeReviewRepository {
  ChallengeReviewRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<ChallengeReviewPage> list({String? status, String? evidence, String? query, int page = 1}) async {
    final response = await _api.get('/staff/challenges/participations', query: <String, dynamic>{
      if (status != null) 'status': status,
      if (evidence != null) 'evidence': evidence,
      if (query?.trim().isNotEmpty ?? false) 'q': query!.trim(),
      'page': page,
      'limit': 20,
    });
    final meta = PageMeta.fromJson(response.meta);
    return ChallengeReviewPage(items: response.dataList.map((entry) {
      final json = asMap(entry);
      return ChallengeReview(
        participationId: str(json, 'id'),
        challengeTitle: str(json, 'challengeTitle'),
        memberFullName: str(json, 'memberFullName'),
        memberCode: str(json, 'memberCode'),
        progressValue: intOf(json, 'progressValue'),
        target: intOf(json, 'target'),
        status: str(json, 'status'),
        evidenceUrl: strOrNull(json, 'evidenceUrl'),
      );
    }).toList(growable: false), page: meta.page, totalPages: meta.totalPages, total: meta.total);
  }

  @override
  Future<void> approveJoin(String participationId) =>
      _api.post('/staff/challenges/participations/$participationId/approve-join');

  @override
  Future<void> approve(String participationId) => _api.post('/staff/challenges/participations/$participationId/approve');
}
