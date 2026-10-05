import '../../../../core/utils/json_utils.dart';
import '../../domain/badge_models.dart';
import '../../domain/rank_models.dart';

/// JSON -> domain mappers for ranks, progress, badges and history.

RankInfo rankInfoFromJson(JsonMap j) => RankInfo(
      id: str(j, 'id'),
      order: intOf(j, 'rankOrder', 1),
      code: str(j, 'code'),
      nameEn: str(j, 'nameEn'),
      nameVi: strOrNull(j, 'nameVi'),
      dpThreshold: intOf(j, 'dpThreshold'),
      minActiveMonths: intOf(j, 'minActiveMonths'),
      requiresTrial: boolOf(j, 'requiresTrial'),
      isHonorary: boolOf(j, 'isHonorary'),
    );

RankProgress rankProgressFromJson(JsonMap j) {
  final next = j['next'];
  return RankProgress(
    current: rankInfoFromJson(asMap(j['current'])),
    next: next is Map ? rankInfoFromJson(asMap(next)) : null,
    status: RankStatus.parse(strOrNull(j, 'status')),
    dpOk: boolOf(j, 'dpOk'),
    timeOk: boolOf(j, 'timeOk'),
    courseOk: boolOf(j, 'courseOk'),
    dpRemaining: intOf(j, 'dpRemaining'),
    monthsIn: doubleOf(j, 'monthsIn'),
    monthsRemaining: doubleOf(j, 'monthsRemaining'),
    trialRequired: boolOf(j, 'trialRequired'),
    trialWaived: boolOf(j, 'trialWaived'),
    trialStatus: TrialStatus.parse(strOrNull(j, 'trialStatus')),
    missingCourses: asList(j['missingCourses'])
        .map((e) => asMap(e))
        .map((m) => MissingCourse(id: str(m, 'id'), name: str(m, 'name')))
        .toList(growable: false),
    peakRankOrder: intOf(j, 'peakRankOrder', 1),
  );
}

/// `GET /me/badges` rows join the history row with its rank: the rank id is `toRankId`.
EarnedBadge earnedBadgeFromJson(JsonMap j) => EarnedBadge(
      rankId: str(j, 'toRankId'),
      rankOrder: intOf(j, 'rankOrder', 1),
      earnedAt: dateOrNull(j, 'earnedAt'),
      reason: strOrNull(j, 'reason'),
    );

RankHistoryEntry rankHistoryFromJson(JsonMap j) => RankHistoryEntry(
      id: str(j, 'id'),
      fromRankId: strOrNull(j, 'fromRankId'),
      toRankId: str(j, 'toRankId'),
      via: RankEarnVia.parse(strOrNull(j, 'earnedVia')),
      reason: str(j, 'reason'),
      dpAtChange: intOf(j, 'dpAtChange'),
      isRevoked: boolOf(j, 'isRevoked'),
      earnedAt: dateOrNull(j, 'earnedAt'),
    );
