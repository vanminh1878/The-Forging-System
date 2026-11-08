import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/open_challenge.dart';

class OpenChallengeRepositoryImpl implements OpenChallengeRepository {
  OpenChallengeRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<OpenChallengePage> list({String? challengeType, int page = 1}) async {
    final response = await _api.get(
      '/me/challenges',
      query: <String, dynamic>{
        'page': page,
        'limit': 20,
        if (challengeType != null) 'challengeType': challengeType,
      },
    );
    final meta = PageMeta.fromJson(response.meta);
    return OpenChallengePage(
      page: meta.page,
      totalPages: meta.totalPages,
      total: meta.total,
      items: response.dataList
          .map((entry) {
            final json = asMap(entry);
            return OpenChallenge(
              id: str(json, 'id'),
              code: str(json, 'code'),
              title: str(json, 'title'),
              description: strOrNull(json, 'description'),
              challengeType: str(json, 'challengeType'),
              context: str(json, 'context'),
              target: intOf(json, 'target'),
              rewardDp: intOf(json, 'rewardDp'),
              rewardMarks: intOf(json, 'rewardMarks'),
              endsAt:
                  dateOrNull(json, 'endsAt') ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              participationId: strOrNull(json, 'participationId'),
              participationStatus: strOrNull(json, 'participationStatus'),
              progressValue: json['progressValue'] == null
                  ? null
                  : intOf(json, 'progressValue'),
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Future<void> join(String challengeId) =>
      _api.post('/me/challenges/$challengeId/join');
}
