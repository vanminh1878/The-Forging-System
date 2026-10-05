import '../../../core/utils/json_utils.dart';
import '../domain/badge_models.dart';
import '../domain/fighter_record_repository.dart';
import '../domain/points_models.dart';
import '../domain/rank_models.dart';
import 'dto/points_dto.dart';
import 'dto/rank_dto.dart';
import 'fighter_record_api.dart';

class FighterRecordRepositoryImpl implements FighterRecordRepository {
  FighterRecordRepositoryImpl(this._api);

  final FighterRecordApi _api;

  @override
  Future<RankProgress> getProgress() async => rankProgressFromJson((await _api.rank()).dataMap);

  @override
  Future<List<RankInfo>> getRanks() async {
    final res = await _api.ranks();
    return res.dataList.map((e) => rankInfoFromJson(asMap(e))).toList(growable: false);
  }

  @override
  Future<List<EarnedBadge>> getBadges() async {
    final res = await _api.badges();
    return res.dataList.map((e) => earnedBadgeFromJson(asMap(e))).toList(growable: false);
  }

  @override
  Future<List<RankHistoryEntry>> getHistory() async {
    final res = await _api.history();
    return res.dataList.map((e) => rankHistoryFromJson(asMap(e))).toList(growable: false);
  }

  @override
  Future<PointsPage> getTransactions({int page = 1, int limit = 20, PointSource? source}) async =>
      pointsPageFromEnvelope(await _api.transactions(page: page, limit: limit, source: source));

  @override
  Future<MonthlyPointStatus> getMonthlyStatus() async =>
      monthlyStatusFromJson((await _api.monthly()).dataMap);

  @override
  Future<void> requestRankTrial() async {
    await _api.requestTrial();
  }
}
