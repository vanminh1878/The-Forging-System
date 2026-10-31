import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/catalog.dart';

/// Detail uses the selected ARM-01 catalogue record; no separate detail API exists.
class RewardDetail extends StatelessWidget {
  const RewardDetail({super.key, required this.reward});
  final ArmoryReward reward;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (reward.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: reward.imageUrl!,
                  height: 160,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) =>
                      Icon(HvpIcons.gift, size: 64, color: context.hvp.gold),
                )
              else
                Icon(HvpIcons.gift, size: 64, color: context.hvp.gold),
              const SizedBox(height: 14),
              Text(reward.name, style: context.txt.titleL),
              if (reward.tierName != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(reward.tierName!, style: context.txt.bodySmall),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                StatusChip(
                    label: '${reward.marksCost} Marks', tone: ChipTone.gold),
                StatusChip(
                    label:
                        reward.stock > 0 ? 'Còn ${reward.stock}' : 'Hết hàng',
                    tone:
                        reward.stock > 0 ? ChipTone.success : ChipTone.danger),
              ]),
              const SizedBox(height: 18),
              HvpCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text('MÔ TẢ', style: context.txt.titleS),
                    const SizedBox(height: 8),
                    Text(
                        reward.description?.isNotEmpty == true
                            ? reward.description!
                            : 'Chưa có mô tả.',
                        style: context.txt.bodySmall),
                  ])),
              const SizedBox(height: 12),
              HvpCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text('ĐIỀU KIỆN ĐỔI', style: context.txt.titleS),
                    const SizedBox(height: 8),
                    _line(context, 'Hạng tối thiểu',
                        reward.minRankName ?? 'Không yêu cầu hạng tối thiểu'),
                    _line(
                        context,
                        'Giới hạn đổi',
                        reward.perMemberLimit == null
                            ? 'Không giới hạn theo cấu hình'
                            : '${reward.perMemberLimit} / ${_period(reward.limitPeriod)}'),
                    if (reward.pickupDays != null)
                      _line(context, 'Thời gian nhận',
                          '${reward.pickupDays} ngày'),
                    if (reward.saleStartsAt != null)
                      _line(context, 'Mở bán từ',
                          formatDate(reward.saleStartsAt!)),
                    if (reward.saleEndsAt != null)
                      _line(context, 'Kết thúc mở bán',
                          formatDate(reward.saleEndsAt!)),
                  ])),
              const SizedBox(height: 12),
              Text('Điều kiện đủ đổi được kiểm tra khi tạo yêu cầu đổi quà.',
                  style: context.txt.caption),
            ]),
      );

  Widget _line(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: context.txt.caption),
              Text(value, style: context.txt.bodySmall),
            ]),
      );

  String _period(String? value) => switch (value) {
        'MONTH' => 'tháng',
        'YEAR' => 'năm',
        'LIFETIME' => 'tài khoản',
        _ => 'chu kỳ',
      };
}
