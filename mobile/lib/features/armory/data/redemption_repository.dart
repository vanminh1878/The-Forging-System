import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/redemption.dart';

class RedemptionRepositoryImpl implements RedemptionRepository {
  RedemptionRepositoryImpl(this.api);
  final ApiClient api;

  @override
  Future<RedemptionPage> history({String? status, int page = 1}) async {
    final response =
        await api.get('/me/armory/redemptions', query: <String, dynamic>{
      'page': page,
      'limit': 20,
      if (status != null) 'status': status,
    });
    final meta = PageMeta.fromJson(response.meta);
    return RedemptionPage(
      items: response.dataList.map(_fromJson).toList(growable: false),
      page: meta.page,
      totalPages: meta.totalPages,
      total: meta.total,
    );
  }

  @override
  Future<ArmoryRedemption> detail(String redemptionId) async {
    final response = await api.get('/me/armory/redemptions/$redemptionId');
    return _fromJson(response.data);
  }

  @override
  Future<void> cancel(String redemptionId, {String? reason}) => api.post(
        '/me/armory/redemptions/$redemptionId/cancel',
        body: <String, dynamic>{
          if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
        },
      );

  ArmoryRedemption _fromJson(Object? value) {
    final json = asMap(value);
    return ArmoryRedemption(
      id: str(json, 'id'),
      code: str(json, 'redemptionCode'),
      rewardName: str(json, 'rewardName'),
      marksCost: intOf(json, 'marksCost'),
      status: str(json, 'status'),
      requestedAt: dateOrNull(json, 'requestedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      pickupBranchName: str(json, 'pickupBranchName'),
      rewardImageUrl: strOrNull(json, 'rewardImageUrl'),
      decidedAt: dateOrNull(json, 'decidedAt'),
      reason: strOrNull(json, 'reason'),
    );
  }
}
