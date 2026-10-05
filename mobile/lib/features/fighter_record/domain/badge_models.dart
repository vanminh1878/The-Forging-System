/// Badges and rank history entities (`GET /me/badges`, `GET /me/rank-history`).
library;

/// How a rank history row came to be.
enum RankEarnVia {
  initial('INITIAL', 'Khởi đầu'),
  autoUpgrade('AUTO_UPGRADE', 'Tự động lên hạng'),
  autoDemote('AUTO_DEMOTE', 'Tụt hạng'),
  restored('RESTORED', 'Khôi phục hạng'),
  rankTrialPassed('RANK_TRIAL_PASSED', 'Vượt qua Rank Trial'),
  manual('MANUAL', 'Điều chỉnh thủ công');

  const RankEarnVia(this.wire, this.label);

  final String wire;

  /// Vietnamese label shown in the timeline.
  final String label;

  static RankEarnVia parse(String? value) {
    for (final via in RankEarnVia.values) {
      if (via.wire == value) return via;
    }
    return RankEarnVia.manual;
  }
}

/// A badge the member currently holds.
class EarnedBadge {
  const EarnedBadge({
    required this.rankId,
    required this.rankOrder,
    required this.earnedAt,
    this.reason,
  });

  final String rankId;
  final int rankOrder;
  final DateTime? earnedAt;
  final String? reason;
}

/// One row of the rank timeline (newest first from the API).
class RankHistoryEntry {
  const RankHistoryEntry({
    required this.id,
    required this.toRankId,
    required this.via,
    required this.reason,
    required this.dpAtChange,
    required this.isRevoked,
    required this.earnedAt,
    this.fromRankId,
  });

  final String id;
  final String? fromRankId;
  final String toRankId;
  final RankEarnVia via;
  final String reason;
  final int dpAtChange;

  /// True for the "badge removed" row written by an automatic demotion.
  final bool isRevoked;
  final DateTime? earnedAt;
}
