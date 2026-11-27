class RankConfiguration {
  const RankConfiguration(
      {required this.id,
      required this.name,
      required this.code,
      required this.minActiveMonths,
      required this.requiresTrial,
      this.approvalRole});
  final String id;
  final String name;
  final String code;
  final int minActiveMonths;
  final bool requiresTrial;
  final String? approvalRole;
}
