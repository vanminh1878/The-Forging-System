import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/catalog.dart';

class ArmoryCatalogRepositoryImpl implements ArmoryCatalogRepository {
  ArmoryCatalogRepositoryImpl(this.api);
  final ApiClient api;

  @override
  Future<List<ArmoryTier>> tiers() async {
    final response = await api.get('/armory/tiers');
    return response.dataList.map((entry) {
      final j = asMap(entry);
      return ArmoryTier(
          code: str(j, 'code'),
          name: str(j, 'name'),
          minMarks: intOf(j, 'minMarks'),
          maxMarks: j['maxMarks'] == null ? null : intOf(j, 'maxMarks'));
    }).toList(growable: false);
  }

  @override
  Future<RewardPage> rewards({String? tierCode, int page = 1}) async {
    final response = await api.get('/armory/rewards', query: <String, dynamic>{
      'page': page,
      'limit': 20,
      if (tierCode != null) 'tierCode': tierCode,
    });
    final meta = PageMeta.fromJson(response.meta);
    return RewardPage(
        page: meta.page,
        totalPages: meta.totalPages,
        total: meta.total,
        items: response.dataList.map((entry) {
          final j = asMap(entry);
          return ArmoryReward(
              id: str(j, 'id'),
              name: str(j, 'name'),
              marksCost: intOf(j, 'marksCost'),
              stock: intOf(j, 'stock'),
              tierName: strOrNull(j, 'tierName'),
              description: strOrNull(j, 'description'),
              imageUrl: strOrNull(j, 'imageUrl'),
              minRankName: strOrNull(j, 'minRankName'),
              perMemberLimit: j['perMemberLimit'] == null
                  ? null
                  : intOf(j, 'perMemberLimit'),
              limitPeriod: strOrNull(j, 'limitPeriod'),
              pickupDays:
                  j['pickupDays'] == null ? null : intOf(j, 'pickupDays'),
              saleStartsAt: dateOrNull(j, 'saleStartsAt'),
              saleEndsAt: dateOrNull(j, 'saleEndsAt'));
        }).toList(growable: false));
  }
}
