import 'badge_models.dart';
import 'points_models.dart';
import 'rank_models.dart';

/// What the Fighter Record screens need from the backend.
/// Presentation depends on this interface only; tests override it with a fake.
abstract class FighterRecordRepository {
  /// `GET /me/rank`
  Future<RankProgress> getProgress();

  /// `GET /ranks` (all 7 ranks, lowest first)
  Future<List<RankInfo>> getRanks();

  /// `GET /me/badges`
  Future<List<EarnedBadge>> getBadges();

  /// `GET /me/rank-history` (newest first)
  Future<List<RankHistoryEntry>> getHistory();

  /// `GET /me/points/transactions?page&limit&source`
  Future<PointsPage> getTransactions({int page = 1, int limit = 20, PointSource? source});

  /// `GET /me/points/monthly`
  Future<MonthlyPointStatus> getMonthlyStatus();

  /// `POST /me/rank-trials`. Throws `ApiException` with code `TRIAL_NOT_AVAILABLE`
  /// or `TRIAL_ALREADY_OPEN` when the request is not allowed.
  Future<void> requestRankTrial();
}
