import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_pagination_bar.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/admin_armory_repository.dart';
import '../admin_armory_providers.dart';
import 'admin_armory_reward_form_screen.dart';
import 'admin_armory_tiers_screen.dart';

class AdminArmoryManagementScreen extends ConsumerStatefulWidget {
  const AdminArmoryManagementScreen(
      {super.key, this.initialTab = 0, this.initialTierCode});
  final int initialTab;
  final String? initialTierCode;

  @override
  ConsumerState<AdminArmoryManagementScreen> createState() =>
      _AdminArmoryManagementScreenState();
}

class _AdminArmoryManagementScreenState
    extends ConsumerState<AdminArmoryManagementScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const HvpAppBar(title: 'Quản lý Armory'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(
            _tab == 0
                ? AdminPaths.armoryTierCreate
                : AdminPaths.armoryRewardCreate,
          ),
          icon: const Icon(HvpIcons.plus),
          label: Text(_tab == 0 ? 'Tạo tier' : 'Tạo quà'),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 0, label: Text('Tier')),
                  ButtonSegment<int>(value: 1, label: Text('Quà tặng')),
                ],
                selected: <int>{_tab},
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
            ),
            Expanded(
                child: _tab == 0
                    ? const _TierList()
                    : _RewardList(initialTierCode: widget.initialTierCode)),
          ],
        ),
      );
}

class _TierList extends ConsumerWidget {
  const _TierList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiers = ref.watch(adminArmoryTiersProvider);
    return AsyncBody<List<AdminArmoryTier>>(
      value: tiers,
      onRetry: () => ref.invalidate(adminArmoryTiersProvider),
      builder: (_, items) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final tier = items[index];
          return HvpCard(
            onTap: () =>
                context.push(AdminPaths.armoryRewardsForTier(tier.code)),
            child: Row(children: <Widget>[
              Icon(HvpIcons.armory, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(tier.name, style: context.txt.titleS),
                  Text(
                      '${tier.code} · ${tier.minMarks}${tier.maxMarks == null ? '+' : '–${tier.maxMarks}'} Marks',
                      style: context.txt.bodySmall),
                ],
              )),
              IconButton(
                tooltip: 'Sửa tier',
                icon: Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => AdminArmoryTiersScreen(tier: tier)));
                  ref.invalidate(adminArmoryTiersProvider);
                },
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _RewardList extends ConsumerStatefulWidget {
  const _RewardList({this.initialTierCode});
  final String? initialTierCode;

  @override
  ConsumerState<_RewardList> createState() => _RewardListState();
}

class _RewardListState extends ConsumerState<_RewardList> {
  late String? _tierCode = widget.initialTierCode;
  String _query = '';
  int _page = 1;
  ({String query, String? tierCode, int page}) get _filter =>
      (query: _query, tierCode: _tierCode, page: _page);

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    final tiers = ref.watch(adminArmoryTiersProvider);
    return Column(children: <Widget>[
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: HvpTextField(
            label: 'Tìm quà tặng',
            hint: 'Tên hoặc SKU',
            prefixIcon: HvpIcons.search,
            onSubmitted: (value) => setState(() {
              _query = value.trim();
              _page = 1;
            }),
          )),
      SizedBox(
          height: 52,
          child: AsyncBody<List<AdminArmoryTier>>(
            value: tiers,
            onRetry: () => ref.invalidate(adminArmoryTiersProvider),
            loading: const SizedBox.shrink(),
            builder: (_, items) => ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: <Widget>[
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: const Text('Tất cả tier'),
                          selected: _tierCode == null,
                          onSelected: (_) => setState(() {
                                _tierCode = null;
                                _page = 1;
                              }))),
                  for (final tier in items)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(tier.name),
                            selected: _tierCode == tier.code,
                            onSelected: (_) => setState(() {
                                  _tierCode = tier.code;
                                  _page = 1;
                                }))),
                ]),
          )),
      Expanded(
          child: AsyncBody<AdminArmoryRewardPage>(
        value: ref.watch(adminArmoryRewardsProvider(filter)),
        onRetry: () => ref.invalidate(adminArmoryRewardsProvider(filter)),
        builder: (_, page) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: page.items.length + (page.totalPages > 1 ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            if (index == page.items.length) {
              return HvpPaginationBar(
                page: page.page,
                totalPages: page.totalPages,
                onPageChanged: (value) => setState(() => _page = value),
              );
            }
            final reward = page.items[index];
            return HvpCard(
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          AdminArmoryRewardFormScreen(reward: reward)));
                  ref.invalidate(adminArmoryRewardsProvider(filter));
                },
                child: Row(children: <Widget>[
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                        Text(reward.name, style: context.txt.titleS),
                        Text(
                            '${reward.sku} · ${reward.marksCost} Marks · tồn ${reward.stock}',
                            style: context.txt.bodySmall),
                      ])),
                  StatusChip(
                      label: reward.isActive ? 'Đang bán' : 'Ngừng bán',
                      tone: reward.isActive
                          ? ChipTone.success
                          : ChipTone.neutral),
                ]));
          },
        ),
      )),
    ]);
  }
}
