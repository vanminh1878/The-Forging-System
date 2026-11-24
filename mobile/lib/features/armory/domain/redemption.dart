class ArmoryRedemption {
  const ArmoryRedemption({
    required this.id,
    required this.code,
    required this.rewardName,
    required this.marksCost,
    required this.status,
    required this.requestedAt,
    required this.pickupBranchName,
    this.rewardImageUrl,
    this.decidedAt,
    this.reason,
  });

  final String id;
  final String code;
  final String rewardName;
  final int marksCost;
  final String status;
  final DateTime requestedAt;
  final String pickupBranchName;
  final String? rewardImageUrl;
  final DateTime? decidedAt;
  final String? reason;
}

class RedemptionPage {
  const RedemptionPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<ArmoryRedemption> items;
  final int page;
  final int totalPages;
  final int total;
}

abstract interface class RedemptionRepository {
  Future<RedemptionPage> history({String? status, int page = 1});
  Future<ArmoryRedemption> detail(String redemptionId);
  Future<void> cancel(String redemptionId, {String? reason});
}
