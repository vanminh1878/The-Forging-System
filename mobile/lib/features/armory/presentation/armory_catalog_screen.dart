import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/catalog.dart';
import 'catalog_providers.dart';

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
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('THE ARMORY', style: context.txt.titleL),
                    const SizedBox(height: 4),
                    Text('Phần quà dành cho hành trình của bạn',
                        style: context.txt.bodySmall),
                    const SizedBox(height: 12),
                    AsyncBody<List<ArmoryTier>>(
                        value: tiers,
                        onRetry: () => ref.invalidate(armoryTiersProvider),
                        loading: const LinearProgressIndicator(),
                        builder: (_, items) => SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: <Widget>[
                                _tierChip(null, 'Tất cả'),
                                for (final tier in items)
                                  _tierChip(tier.code, tier.name),
                              ]),
                            )),
                  ])),
          Expanded(
              child: AsyncBody<RewardPage>(
                  value: rewards,
                  onRetry: () => ref.invalidate(armoryRewardsProvider(query)),
                  builder: (_, result) => RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(armoryTiersProvider);
                        ref.invalidate(armoryRewardsProvider(query));
                        await ref.read(armoryRewardsProvider(query).future);
                      },
                      child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
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
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RewardCard(reward: reward)),
                            if (result.totalPages > 1)
                              Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  children: <Widget>[
                                    TextButton(
                                        onPressed: result.page > 1
                                            ? () => setState(
                                                () => page = result.page - 1)
                                            : null,
                                        child: const Text('Trang trước')),
                                    TextButton(
                                        onPressed: result.page <
                                                result.totalPages
                                            ? () => setState(
                                                () => page = result.page + 1)
                                            : null,
                                        child: const Text('Trang sau')),
                                  ]),
                          ])))),
        ]);
  }

  Widget _tierChip(String? code, String title) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: tierCode == code,
        onSelected: (_) => setState(() {
          tierCode = code;
          page = 1;
        }),
      ));
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward});
  final ArmoryReward reward;
  @override
  Widget build(BuildContext context) => HvpCard(
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
                        Text(reward.name, style: context.txt.titleM),
                        if (reward.tierName != null)
                          Text(reward.tierName!, style: context.txt.caption),
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
                  label: '${reward.marksCost} Marks', tone: ChipTone.gold),
              StatusChip(
                  label: reward.stock > 0 ? 'Còn ${reward.stock}' : 'Hết hàng',
                  tone: reward.stock > 0 ? ChipTone.success : ChipTone.danger),
            ]),
            if (reward.minRankName != null) ...<Widget>[
              const SizedBox(height: 8),
              Text('Hạng tối thiểu: ${reward.minRankName}',
                  style: context.txt.caption)
            ],
            if (reward.perMemberLimit != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
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
