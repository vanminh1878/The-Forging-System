import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/admin_challenge.dart';

class AdminChallengeRepositoryImpl implements AdminChallengeRepository {
  AdminChallengeRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<AdminChallengePage> list(
      {String? query,
      String? status,
      String? challengeType,
      String? context,
      int page = 1}) async {
    final response =
        await _api.get('/admin/challenges', query: <String, dynamic>{
      'page': page,
      'limit': 20,
      if (query?.trim().isNotEmpty ?? false) 'q': query!.trim(),
      if (status != null) 'status': status,
      if (challengeType != null) 'challengeType': challengeType,
      if (context != null) 'context': context,
    });
    final meta = PageMeta.fromJson(response.meta);
    return AdminChallengePage(
        items: response.dataList
            .map((v) => _fromJson(asMap(v)))
            .toList(growable: false),
        page: meta.page,
        totalPages: meta.totalPages,
        total: meta.total);
  }

  @override
  Future<AdminChallenge> detail(String id) async =>
      _fromJson((await _api.get('/admin/challenges/$id')).dataMap);

  @override
  Future<void> create(ChallengeInput input) =>
      _api.post('/admin/challenges', body: _body(input));

  @override
  Future<void> update(String id, ChallengeInput input, String reason) =>
      _api.patch('/admin/challenges/$id',
          body: <String, dynamic>{..._body(input), 'reason': reason.trim()});

  @override
  Future<void> setEnabled(String id,
          {required bool enabled, required String reason}) =>
      _api.patch('/admin/challenges/$id/status',
          body: <String, dynamic>{'enabled': enabled, 'reason': reason.trim()});

  Map<String, dynamic> _body(ChallengeInput value) => <String, dynamic>{
        if (value.code?.trim().isNotEmpty ?? false)
          'code': value.code!.trim().toUpperCase(),
        'title': value.title.trim(),
        'description': value.description?.trim().isEmpty ?? true
            ? null
            : value.description!.trim(),
        'challengeType': value.challengeType,
        'context': value.context,
        'target': value.target,
        'rewardDp': value.rewardDp,
        'rewardMarks': value.rewardMarks,
        'joinApproval': value.joinApproval,
        'completionMethod': value.completionMethod,
        'startsAt': value.startsAt.toUtc().toIso8601String(),
        'endsAt': value.endsAt.toUtc().toIso8601String(),
      };

  AdminChallenge _fromJson(JsonMap j) => AdminChallenge(
        id: str(j, 'id'),
        code: strOrNull(j, 'code'),
        title: str(j, 'title'),
        description: strOrNull(j, 'description'),
        challengeType: str(j, 'challengeType'),
        context: str(j, 'context'),
        target: intOf(j, 'target'),
        rewardDp: intOf(j, 'rewardDp'),
        rewardMarks: intOf(j, 'rewardMarks'),
        startsAt:
            dateOrNull(j, 'startsAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
        endsAt:
            dateOrNull(j, 'endsAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
        status: str(j, 'status'),
        joinApproval: strOrNull(j, 'joinApproval') ?? 'COACH',
        completionMethod: strOrNull(j, 'completionMethod') ?? 'EVIDENCE',
      );
}
