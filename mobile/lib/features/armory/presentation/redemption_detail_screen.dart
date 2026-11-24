import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/redemption_status_chip.dart';
import '../domain/redemption.dart';
import 'redemption_providers.dart';

class RedemptionDetailScreen extends ConsumerStatefulWidget {
  const RedemptionDetailScreen({super.key, required this.redemptionId});
  final String redemptionId;

  @override
  ConsumerState<RedemptionDetailScreen> createState() =>
      _RedemptionDetailScreenState();
}

class _RedemptionDetailScreenState
    extends ConsumerState<RedemptionDetailScreen> {
  bool _cancelling = false;
  String? _cancelError;

  Future<void> _cancel(ArmoryRedemption redemption) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Hủy yêu cầu đổi quà',
      message:
          'Hủy yêu cầu ${redemption.code}? Marks đang giữ và tồn kho sẽ được hoàn lại.',
      confirmLabel: 'Hủy yêu cầu',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _cancelling = true;
      _cancelError = null;
    });
    try {
      await ref.read(redemptionRepositoryProvider).cancel(redemption.id);
      ref.invalidate(redemptionDetailProvider(redemption.id));
      ref.invalidate(redemptionHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy yêu cầu đổi quà.')));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _cancelError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _cancelError = 'Không thể hủy yêu cầu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final redemptionId = widget.redemptionId;
    final detail = ref.watch(redemptionDetailProvider(redemptionId));
    return Scaffold(
      appBar: const HvpAppBar(title: 'Chi tiết đổi quà'),
      body: AsyncBody<ArmoryRedemption>(
        value: detail,
        onRetry: () => ref.invalidate(redemptionDetailProvider(redemptionId)),
        builder: (_, redemption) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Center(
              child: redemption.rewardImageUrl == null
                  ? Icon(HvpIcons.gift, size: 72, color: context.hvp.gold)
                  : CachedNetworkImage(
                      imageUrl: redemption.rewardImageUrl!,
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => Icon(HvpIcons.gift,
                          size: 72, color: context.hvp.gold),
                    ),
            ),
            const SizedBox(height: 16),
            Text(redemption.rewardName,
                style: context.txt.titleL, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Center(child: RedemptionStatusChip(status: redemption.status)),
            const SizedBox(height: 20),
            HvpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('THÔNG TIN YÊU CẦU', style: context.txt.titleS),
                    const SizedBox(height: 8),
                    _line(context, 'Mã yêu cầu', redemption.code),
                    _line(context, 'Marks đã đổi',
                        '${formatInt(redemption.marksCost)} Marks'),
                    _line(
                        context, 'Chi nhánh nhận', redemption.pickupBranchName),
                    _line(context, 'Thời điểm yêu cầu',
                        formatDateTime(redemption.requestedAt)),
                    if (redemption.decidedAt != null)
                      _line(context, 'Cập nhật lần cuối',
                          formatDateTime(redemption.decidedAt!)),
                  ]),
            ),
            if (redemption.reason != null) ...<Widget>[
              const SizedBox(height: 12),
              HvpCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('GHI CHÚ', style: context.txt.titleS),
                      const SizedBox(height: 8),
                      Text(redemption.reason!, style: context.txt.bodySmall),
                    ]),
              ),
            ],
            if (redemption.status == 'PENDING_PICKUP' ||
                redemption.status == 'READY_PICKUP') ...<Widget>[
              const SizedBox(height: 16),
              HvpButton.danger(
                label: 'Hủy yêu cầu đổi quà',
                expand: true,
                loading: _cancelling,
                onPressed: _cancelling ? null : () => _cancel(redemption),
              ),
              if (_cancelError != null) ...<Widget>[
                const SizedBox(height: 12),
                InlineBanner(message: _cancelError!),
              ],
            ],
          ],
        ),
      ),
    );
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
}
