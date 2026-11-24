import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/redemption_create.dart';

class RedemptionCreateRepositoryImpl implements RedemptionCreateRepository {
  RedemptionCreateRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<CreatedRedemption> create({
    required String rewardId,
    required String pickupBranchId,
    required String idempotencyKey,
  }) async {
    final response = await _api.post(
      '/armory/redemptions',
      body: <String, String>{
        'rewardId': rewardId,
        'pickupBranchId': pickupBranchId,
        'idempotencyKey': idempotencyKey,
      },
    );
    return CreatedRedemption.fromJson(asMap(response.dataMap['redemption']));
  }
}
