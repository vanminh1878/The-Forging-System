class ArmoryTier {
  const ArmoryTier(
      {required this.code,
      required this.name,
      required this.minMarks,
      this.maxMarks});
  final String code;
  final String name;
  final int minMarks;
  final int? maxMarks;
}

class ArmoryReward {
  const ArmoryReward(
      {required this.id,
      required this.name,
      required this.marksCost,
      required this.stock,
      this.tierName,
      this.description,
      this.imageUrl,
      this.minRankName,
      this.perMemberLimit,
      this.limitPeriod});
  final String id;
  final String name;
  final int marksCost;
  final int stock;
  final String? tierName;
  final String? description;
  final String? imageUrl;
  final String? minRankName;
  final int? perMemberLimit;
  final String? limitPeriod;
}

class RewardPage {
  const RewardPage(
      {required this.items,
      required this.page,
      required this.totalPages,
      required this.total});
  final List<ArmoryReward> items;
  final int page;
  final int totalPages;
  final int total;
}

abstract interface class ArmoryCatalogRepository {
  Future<List<ArmoryTier>> tiers();
  Future<RewardPage> rewards({String? tierCode, int page = 1});
}
