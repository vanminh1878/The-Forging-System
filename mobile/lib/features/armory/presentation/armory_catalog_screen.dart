import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_filter_chip.dart';
import '../../../core/widgets/hvp_pagination_bar.dart';
import '../../../core/widgets/hvp_refresh_overlay.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/catalog.dart';
import '../domain/wallet.dart';
import 'catalog_providers.dart';
import 'reward_detail.dart';
import 'wallet_providers.dart';

class ArmoryCatalogScreen extends ConsumerStatefulWidget {
  const ArmoryCatalogScreen({super.key});
  @override
  ConsumerState<ArmoryCatalogScreen> createState() =>
      _ArmoryCatalogScreenState();
}

class _ArmoryCatalogScreenState extends ConsumerState<ArmoryCatalogScreen> {
  String? tierCode;
  int page = 1;

  @override
  Widget build(BuildContext context) {
    final tiers = ref.watch(armoryTiersProvider);
    final query = (tierCode: tierCode, page: page);
    final rewards = ref.watch(armoryRewardsProvider(query));
    final wallet = ref.watch(armoryWalletProvider);
    final refreshing = rewards.isRefreshing && rewards.hasValue;

    void refresh() {
      ref.invalidate(armoryTiersProvider);
      ref.invalidate(armoryRewardsProvider(query));
      ref.invalidate(armoryWalletProvider);
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                      HvpButton.gold(
                        label: 'Lịch sử đổi quà',
                        icon: HvpIcons.history,
                        small: true,
                        onPressed: () =>
                            context.push(StudentPaths.armoryRedemptions),
                      ),
                      HvpRefreshButton(
                          refreshing: refreshing, onPressed: refresh),
                    ]),
                    const SizedBox(height: 12),
                    _WalletSummary(value: wallet),
                    const SizedBox(height: 8),
                    AsyncBody<List<ArmoryTier>>(
                        value: tiers,
                        onRetry: () => ref.invalidate(armoryTiersProvider),
                        loading: const LinearProgressIndicator(),
                        builder: (_, items) => SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: <Widget>[
                                _tierChip(null, 'Tất cả', HvpIcons.all),
                                for (final tier in items)
                                  _tierChip(tier.code, tier.name, HvpIcons.tag),
                              ]),
                            )),
                  ])),
          Expanded(
              child: HvpRefreshOverlay(
                  refreshing: refreshing,
                  label: 'Đang tải phần quà…',
                  child: AsyncBody<RewardPage>(
                      value: rewards,
                      onRetry: () =>
                          ref.invalidate(armoryRewardsProvider(query)),
                      builder: (_, result) => RefreshIndicator(
                          onRefresh: () async {
                            refresh();
                            await ref.read(armoryRewardsProvider(query).future);
                            await ref.read(armoryWalletProvider.future);
                          },
                          child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, HvpLayout.navClearance),
                              children: <Widget>[
                                Text(
                                    '${result.total} phần quà · Trang ${result.page}/${result.totalPages}',
                                    style: context.txt.caption),
                                const SizedBox(height: 12),
                                if (result.items.isEmpty)
                                  const EmptyState(
                                      icon: HvpIcons.gift,
                                      title: 'Chưa có phần quà',
                                      message:
                                          'Hiện chưa có quà mở bán trong tầng này.'),
                                for (final reward in result.items)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _RewardCard(reward: reward)),
                                HvpPaginationBar(
                                  page: result.page,
                                  totalPages: result.totalPages,
                                  onPageChanged: (value) =>
                                      setState(() => page = value),
                                ),
                              ]))))),
        ]);
  }

  Widget _tierChip(String? code, String title, IconData icon) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: HvpFilterChip(
        label: title,
        icon: icon,
        selected: tierCode == code,
        onSelected: () => setState(() {
          tierCode = code;
          page = 1;
        }),
      ));
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({required this.value});
  final AsyncValue<ArmoryWallet> value;

  @override
  Widget build(BuildContext context) => value.when(
        loading: () =>
            const SizedBox(height: 68, child: LinearProgressIndicator()),
        error: (_, __) => HvpCard(
          accent: context.hvp.red,
          child: Row(children: <Widget>[
            Icon(HvpIcons.warning, color: context.hvp.red),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Không tải được ví Marks.',
                    style: context.txt.bodySmall)),
          ]),
        ),
        data: (wallet) => HvpCard(
          highlighted: true,
          child: Row(children: <Widget>[
            Icon(HvpIcons.coins, size: 32, color: context.hvp.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('MARKS KHẢ DỤNG', style: context.txt.caption),
                    Text('${formatInt(wallet.marksAvailable)} Marks',
                        style: context.txt.titleM),
                  ]),
            ),
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  IconLabel(
                      icon: HvpIcons.limit,
                      iconSize: 13,
                      label: 'Đang giữ',
                      style: context.txt.caption),
                  Text('${formatInt(wallet.marksHeld)} Marks',
                      style: context.txt.bodySmall),
                  if (!wallet.canRedeem)
                    Text('Chưa thể đổi',
                        style: context.txt.caption
                            .copyWith(color: context.hvp.red)),
                ]),
          ]),
        ),
      );
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward});
  final ArmoryReward reward;
  @override
  Widget build(BuildContext context) => HvpCard(
      semanticLabel: 'Xem chi tiết ${reward.name}',
      onTap: () => showHvpSheet<void>(context,
          title: 'Chi tiết phần quà',
          builder: (_) => RewardDetail(reward: reward)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (reward.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: reward.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Icon(HvpIcons.gift, color: context.hvp.gold),
                    )
                  else
                    Icon(HvpIcons.gift, color: context.hvp.gold),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                        Text(reward.name,
                            style: context.txt.titleM,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (reward.tierName != null)
                          IconLabel(
                              icon: HvpIcons.tag,
                              iconSize: 13,
                              label: reward.tierName!,
                              style: context.txt.caption),
                      ])),
                ]),
            if (reward.description != null &&
                reward.description!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(reward.description!, style: context.txt.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              StatusChip(
                  label: '${reward.marksCost} Marks',
                  tone: ChipTone.gold,
                  icon: HvpIcons.coins),
              StatusChip(
                  label: reward.stock > 0 ? 'Còn ${reward.stock}' : 'Hết hàng',
                  tone: reward.stock > 0 ? ChipTone.success : ChipTone.danger,
                  icon: reward.stock > 0 ? HvpIcons.stock : HvpIcons.block),
            ]),
            if (reward.minRankName != null) ...<Widget>[
              const SizedBox(height: 8),
              IconLabel(
                  icon: HvpIcons.medal,
                  label: 'Hạng tối thiểu: ${reward.minRankName}',
                  style: context.txt.caption)
            ],
            if (reward.perMemberLimit != null) ...<Widget>[
              const SizedBox(height: 4),
              IconLabel(
                  icon: HvpIcons.limit,
                  label:
                      'Giới hạn: ${reward.perMemberLimit} / ${_period(reward.limitPeriod)}',
                  style: context.txt.caption)
            ],
          ]));
  String _period(String? value) => switch (value) {
        'MONTH' => 'tháng',
        'YEAR' => 'năm',
        'LIFETIME' => 'tài khoản',
        _ => 'chu kỳ'
      };
}
