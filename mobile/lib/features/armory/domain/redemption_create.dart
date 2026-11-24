import '../../../core/utils/json_utils.dart';

class CreatedRedemption {
  const CreatedRedemption({
    required this.id,
    required this.code,
    required this.marksCost,
    required this.status,
  });

  factory CreatedRedemption.fromJson(JsonMap json) => CreatedRedemption(
        id: str(json, 'id'),
        code: str(json, 'redemptionCode'),
        marksCost: intOf(json, 'marksCost'),
        status: str(json, 'status'),
      );

  final String id;
  final String code;
  final int marksCost;
  final String status;
}

abstract interface class RedemptionCreateRepository {
  Future<CreatedRedemption> create({
    required String rewardId,
    required String pickupBranchId,
    required String idempotencyKey,
  });
}
