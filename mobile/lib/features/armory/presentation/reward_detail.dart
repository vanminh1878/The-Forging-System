import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branch/branch.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/branch_picker.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/catalog.dart';
import '../domain/redemption_create.dart';
import 'redemption_create_providers.dart';

/// Detail uses the selected ARM-01 catalogue record; no separate detail API exists.
class RewardDetail extends ConsumerStatefulWidget {
  const RewardDetail({super.key, required this.reward});
  final ArmoryReward reward;

  @override
  ConsumerState<RewardDetail> createState() => _RewardDetailState();
}

class _RewardDetailState extends ConsumerState<RewardDetail> {
  Branch? _pickupBranch;
  bool _submitting = false;
  String? _error;
  CreatedRedemption? _created;
  late final String _idempotencyKey = _uuidV4();

  ArmoryReward get reward => widget.reward;

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
              const SizedBox(height: 16),
              if (_created != null)
                _Success(redemption: _created!, branch: _pickupBranch!)
              else ...<Widget>[
                BranchPicker(
                  selectedId: _pickupBranch?.id,
                  label: 'Chi nhánh nhận quà',
                  onChanged: (branch) => setState(() {
                    _pickupBranch = branch;
                    _error = null;
                  }),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  InlineBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                HvpButton.gold(
                  label: reward.stock > 0
                      ? 'Đổi quà · ${reward.marksCost} Marks'
                      : 'Quà đã hết hàng',
                  icon: HvpIcons.gift,
                  expand: true,
                  loading: _submitting,
                  onPressed: reward.stock > 0 && !_submitting
                      ? _confirmAndRedeem
                      : null,
                ),
              ],
            ]),
      );

  Future<void> _confirmAndRedeem() async {
    final branch = _pickupBranch;
    if (branch == null) {
      setState(() => _error = 'Vui lòng chọn chi nhánh nhận quà.');
      return;
    }
    final confirmed = await showConfirmSheet(
      context,
      title: 'Xác nhận đổi quà',
      message:
          'Bạn sẽ đổi ${reward.name} với giá ${formatInt(reward.marksCost)} Marks và nhận tại ${branch.name}. Marks sẽ được giữ cho đến khi bạn nhận quà.',
      confirmLabel: 'Xác nhận đổi quà',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref.read(redemptionCreateRepositoryProvider).create(
            rewardId: reward.id,
            pickupBranchId: branch.id,
            idempotencyKey: _idempotencyKey,
          );
      if (!mounted) return;
      setState(() => _created = created);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Không thể tạo yêu cầu đổi quà. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _Success extends StatelessWidget {
  const _Success({required this.redemption, required this.branch});
  final CreatedRedemption redemption;
  final Branch branch;

  @override
  Widget build(BuildContext context) => HvpCard(
        accent: context.hvp.emerald,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Icon(HvpIcons.checkCircle, color: context.hvp.emerald),
                const SizedBox(width: 8),
                Text('ĐỔI QUÀ THÀNH CÔNG', style: context.txt.titleS),
              ]),
              const SizedBox(height: 10),
              Text('Mã yêu cầu: ${redemption.code}',
                  style: context.txt.bodySmall),
              Text(
                  'Nhận quà tại ${branch.name}. ${formatInt(redemption.marksCost)} Marks đang được giữ.',
                  style: context.txt.bodySmall),
            ]),
      );
}
