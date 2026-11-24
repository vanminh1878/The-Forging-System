import 'package:flutter/widgets.dart';

import 'status_chip.dart';

String redemptionStatusLabel(String status) => switch (status) {
      'PENDING_PICKUP' => 'Chờ duyệt',
      'READY_PICKUP' => 'Sẵn sàng nhận',
      'DELIVERED' => 'Đã giao',
      'REJECTED' => 'Từ chối',
      'CANCELLED' => 'Đã hủy',
      'EXPIRED' => 'Hết hạn',
      _ => status,
    };

ChipTone redemptionStatusTone(String status) => switch (status) {
      'PENDING_PICKUP' => ChipTone.warning,
      'READY_PICKUP' || 'DELIVERED' => ChipTone.success,
      'REJECTED' => ChipTone.danger,
      _ => ChipTone.neutral,
    };

/// Consistent Armory redemption status presentation for member and reception UI.
class RedemptionStatusChip extends StatelessWidget {
  const RedemptionStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(
      label: redemptionStatusLabel(status), tone: redemptionStatusTone(status));
}
