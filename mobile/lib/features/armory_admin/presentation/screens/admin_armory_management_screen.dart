import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_filter_chip.dart';
import '../../../../core/widgets/hvp_sub_nav.dart';
import '../../../../core/widgets/icon_label.dart';
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
    extends ConsumerState<AdminArmoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, initialIndex: widget.initialTab, vsync: this)
        ..addListener(_onTab);
  late int _tab = widget.initialTab;

  void _onTab() {
    if (_tabs.index != _tab) setState(() => _tab = _tabs.index);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const HvpAppBar(
            title: 'Quản lý Armory', titleIcon: HvpIcons.armoryFill),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(
            _tab == 0
                ? AdminPaths.armoryTierCreate
                : AdminPaths.armoryRewardCreate,
          ),
          icon: Icon(_tab == 0 ? HvpIcons.newTier : HvpIcons.newGift),
          label: Text(_tab == 0 ? 'Tạo tier' : 'Tạo quà'),
        ),
        body: Column(
          children: <Widget>[
            HvpSubNav(
              controller: _tabs,
              items: const <HvpSubNavItem>[
                HvpSubNavItem(label: 'Tier', icon: HvpIcons.tag),
                HvpSubNavItem(label: 'Quà tặng', icon: HvpIcons.gift),
              ],
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
                  IconLabel(
                      icon: HvpIcons.coins,
                      label:
                          '${tier.code} · ${tier.minMarks}${tier.maxMarks == null ? '+' : '–${tier.maxMarks}'} Marks'),
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
          height: 60,
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
                      child: HvpFilterChip(
                          label: 'Tất cả tier',
                          icon: HvpIcons.all,
                          selected: _tierCode == null,
                          onSelected: () => setState(() {
                                _tierCode = null;
                                _page = 1;
                              }))),
                  for (final tier in items)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: HvpFilterChip(
                            label: tier.name,
                            icon: HvpIcons.tag,
                            selected: _tierCode == tier.code,
                            onSelected: () => setState(() {
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
                        IconLabel(
                            icon: HvpIcons.gift,
                            iconSize: 18,
                            label: reward.name,
                            style: context.txt.titleS),
                        IconLabel(
                            icon: HvpIcons.coins,
                            label:
                                '${reward.sku} · ${reward.marksCost} Marks · tồn ${reward.stock}'),
                      ])),
                  StatusChip(
                      label: reward.isActive ? 'Đang bán' : 'Ngừng bán',
                      icon: reward.isActive
                          ? HvpIcons.storefront
                          : HvpIcons.block,
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
