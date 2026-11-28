import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_filter_chip.dart';
import '../../../core/widgets/hvp_pagination_bar.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/redemption_status_chip.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/redemption.dart';
import 'redemption_providers.dart';

class RedemptionHistoryScreen extends ConsumerStatefulWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  ConsumerState<RedemptionHistoryScreen> createState() =>
      _RedemptionHistoryScreenState();
}

class _RedemptionHistoryScreenState
    extends ConsumerState<RedemptionHistoryScreen> {
  String? status;
  int page = 1;

  @override
  Widget build(BuildContext context) {
    final query = (status: status, page: page);
    final history = ref.watch(redemptionHistoryProvider(query));
    return Scaffold(
      appBar: const HvpAppBar(
          title: 'Lịch sử đổi quà', titleIcon: HvpIcons.history),
      body: Column(children: <Widget>[
        SizedBox(
          height: 56,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _filterChip(null, 'Tất cả'),
              _filterChip(
                  'PENDING_PICKUP', redemptionStatusLabel('PENDING_PICKUP')),
              _filterChip(
                  'READY_PICKUP', redemptionStatusLabel('READY_PICKUP')),
              _filterChip('DELIVERED', redemptionStatusLabel('DELIVERED')),
              _filterChip('REJECTED', redemptionStatusLabel('REJECTED')),
              _filterChip('CANCELLED', redemptionStatusLabel('CANCELLED')),
              _filterChip('EXPIRED', redemptionStatusLabel('EXPIRED')),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody<RedemptionPage>(
            value: history,
            onRetry: () => ref.invalidate(redemptionHistoryProvider(query)),
            builder: (_, result) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(redemptionHistoryProvider(query));
                await ref.read(redemptionHistoryProvider(query).future);
              },
              child: result.items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const <Widget>[
                        EmptyState(
                          icon: HvpIcons.history,
                          title: 'Chưa có yêu cầu đổi quà',
                          message:
                              'Các phần quà bạn đã đổi sẽ xuất hiện tại đây.',
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: <Widget>[
                        Text('${result.total} yêu cầu',
                            style: context.txt.caption),
                        const SizedBox(height: 8),
                        for (final redemption in result.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RedemptionCard(redemption: redemption),
                          ),
                        HvpPaginationBar(
                          page: result.page,
                          totalPages: result.totalPages,
                          onPageChanged: (value) =>
                              setState(() => page = value),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _filterChip(String? value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: HvpFilterChip(
          label: label,
          icon: value == null ? HvpIcons.all : redemptionStatusIcon(value),
          selected: status == value,
          onSelected: () => setState(() {
            status = value;
            page = 1;
          }),
        ),
      );
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({required this.redemption});
  final ArmoryRedemption redemption;

  @override
  Widget build(BuildContext context) => HvpCard(
        onTap: () =>
            context.push('/student/armory/redemptions/${redemption.id}'),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _image(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(redemption.rewardName, style: context.txt.titleS),
                      const SizedBox(height: 4),
                      IconLabel(
                          icon: HvpIcons.receipt,
                          iconSize: 13,
                          label:
                              '#${redemption.code} · ${formatDateTime(redemption.requestedAt)}',
                          style: context.txt.caption),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: <Widget>[
                        StatusChip(
                            label: '${formatInt(redemption.marksCost)} Marks',
                            tone: ChipTone.gold,
                            icon: HvpIcons.coins),
                        RedemptionStatusChip(status: redemption.status),
                      ]),
                    ]),
              ),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
            ]),
      );

  Widget _image(BuildContext context) => redemption.rewardImageUrl == null
      ? Icon(HvpIcons.gift, size: 42, color: context.hvp.gold)
      : CachedNetworkImage(
          imageUrl: redemption.rewardImageUrl!,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              Icon(HvpIcons.gift, size: 42, color: context.hvp.gold),
        );
}
