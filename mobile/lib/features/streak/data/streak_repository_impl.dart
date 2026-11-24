import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/streak.dart';

class StreakRepositoryImpl implements StreakRepository {
  StreakRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<StreakSummary> summary() async {
    final json = (await _api.get('/me/streak')).dataMap;
    return StreakSummary(
      currentStreakWeeks: intOf(json, 'currentStreakWeeks'),
      longestStreakWeeks: intOf(json, 'longestStreakWeeks'),
      currentWeekStart: dateOrNull(json, 'currentWeekStart') ?? DateTime.fromMillisecondsSinceEpoch(0),
      sessionsThisWeek: intOf(json, 'sessionsThisWeek'),
      targetSessions: intOf(json, 'targetSessions'),
      availableFreezes: intOf(json, 'availableFreezes'),
      logs: listOf(json['logs']).map((value) {
        final log = asMap(value);
        return StreakLog(
          weekStart: dateOrNull(log, 'weekStart') ?? DateTime.fromMillisecondsSinceEpoch(0),
          sessionsCount: intOf(log, 'sessionsCount'),
          targetSessions: intOf(log, 'targetSessions'),
          result: str(log, 'result'),
          streakBefore: intOf(log, 'streakBefore'),
          streakAfter: intOf(log, 'streakAfter'),
        );
      }).toList(growable: false),
    );
  }
}
