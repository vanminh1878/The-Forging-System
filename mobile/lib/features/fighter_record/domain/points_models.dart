/// Point ledger entities (`GET /me/points/transactions`, `GET /me/points/monthly`).
library;

/// Ledger sources, with the Vietnamese label shown to members.
enum PointSource {
  opening('OPENING', 'Điểm khởi đầu'),
  session('SESSION', 'Buổi tập'),
  attitude('ATTITUDE', 'Thái độ tập luyện'),
  academy('ACADEMY', 'Học viện'),
  streakMilestone('STREAK_MILESTONE', 'Mốc chuỗi tập'),
  challenge('CHALLENGE', 'Thử thách'),
  rankTrial('RANK_TRIAL', 'Thưởng Rank Trial'),
  earlyRenewal('EARLY_RENEWAL', 'Gia hạn sớm'),
  comeback('COMEBACK', 'Quay lại tập'),
  armoryRedeem('ARMORY_REDEEM', 'Đổi quà Armory'),
  manualAdjustment('MANUAL_ADJUSTMENT', 'Điều chỉnh'),
  reversal('REVERSAL', 'Đảo giao dịch'),
  other('OTHER', 'Khác');

  const PointSource(this.wire, this.label);

  /// Value of the `source` query parameter / response field.
  final String wire;
  final String label;

  static PointSource parse(String? value) {
    for (final source in PointSource.values) {
      if (source.wire == value) return source;
    }
    return PointSource.other;
  }

  /// Sources a member can filter on (everything the API accepts).
  static List<PointSource> get filterable =>
      PointSource.values.where((s) => s != PointSource.other).toList(growable: false);
}

class PointTransaction {
  const PointTransaction({
    required this.id,
    required this.source,
    required this.dpAmount,
    required this.marksAmount,
    required this.isCapped,
    required this.occurredAt,
    this.note,
  });

  final String id;
  final PointSource source;
  final int dpAmount;
  final int marksAmount;

  /// Part of the award was cut by the monthly cap.
  final bool isCapped;
  final DateTime? occurredAt;
  final String? note;
}

/// One page of the ledger.
class PointsPage {
  const PointsPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<PointTransaction> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
}

/// Usage of the monthly DP / Marks caps.
class MonthlyPointStatus {
  const MonthlyPointStatus({
    required this.dpUsed,
    required this.dpCap,
    required this.marksUsed,
    required this.marksCap,
  });

  final int dpUsed;
  final int dpCap;
  final int marksUsed;
  final int marksCap;

  static double _fraction(int used, int cap) {
    if (cap <= 0) return 0;
    final f = used / cap;
    if (f < 0) return 0;
    return f > 1 ? 1 : f;
  }

  double get dpFraction => _fraction(dpUsed, dpCap);
  double get marksFraction => _fraction(marksUsed, marksCap);
  bool get dpCapReached => dpCap > 0 && dpUsed >= dpCap;
  bool get marksCapReached => marksCap > 0 && marksUsed >= marksCap;
}
