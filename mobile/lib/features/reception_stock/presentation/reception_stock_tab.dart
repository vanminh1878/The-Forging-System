import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_filter_chip.dart';
import '../../../core/widgets/hvp_pagination_bar.dart';
import '../../../core/widgets/hvp_sub_nav.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../../../core/widgets/hvp_toast.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/inventory.dart';
import 'inventory_providers.dart';

/// Reception "Kho quà" tab: adjust stock and review the movement history (GFT-02).
class ReceptionStockTab extends ConsumerStatefulWidget {
  const ReceptionStockTab({super.key});

  @override
  ConsumerState<ReceptionStockTab> createState() => _ReceptionStockTabState();
}

class _ReceptionStockTabState extends ConsumerState<ReceptionStockTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HvpSubNav(
          controller: _tabs,
          items: const <HvpSubNavItem>[
            HvpSubNavItem(label: 'Tồn kho', icon: HvpIcons.package),
            HvpSubNavItem(label: 'Lịch sử', icon: HvpIcons.history),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const <Widget>[
              _StockCatalogTab(),
              _StockHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockCatalogTab extends ConsumerStatefulWidget {
  const _StockCatalogTab();

  @override
  ConsumerState<_StockCatalogTab> createState() => _StockCatalogTabState();
}

class _StockCatalogTabState extends ConsumerState<_StockCatalogTab> {
  String _query = '';
  int _page = 1;

  Future<void> _adjust(InventoryReward reward, String movementType) async {
    await showHvpSheet<void>(context,
        title: movementType == 'IN' ? 'Nhập kho' : 'Xuất kho',
        builder: (_) => SizedBox(
              height: 560,
              child:
                  _StockAdjustTab(reward: reward, movementType: movementType),
            ));
    if (mounted) ref.invalidate(inventoryRewardsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final filter = (query: _query, page: _page);
    return Column(children: <Widget>[
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: HvpTextField(
            label: 'Tìm quà trong kho',
            hint: 'Tên hoặc SKU',
            prefixIcon: HvpIcons.search,
            onSubmitted: (value) => setState(() {
              _query = value.trim();
              _page = 1;
            }),
          )),
      Expanded(
          child: AsyncBody<InventoryRewardPage>(
        value: ref.watch(inventoryRewardsProvider(filter)),
        onRetry: () => ref.invalidate(inventoryRewardsProvider(filter)),
        builder: (_, page) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(inventoryRewardsProvider(filter));
            await ref.read(inventoryRewardsProvider(filter).future);
          },
          child: page.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const <Widget>[
                      SizedBox(
                          height: 340,
                          child: EmptyState(
                              icon: HvpIcons.package,
                              title: 'Chưa có phần quà',
                              message:
                                  'Danh sách phần quà trong kho sẽ hiện tại đây.'))
                    ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      16, 8, 16, HvpLayout.navClearance),
                  children: <Widget>[
                      Text(
                          '${page.total} phần quà · Trang ${page.page}/${page.totalPages}',
                          style: context.txt.caption),
                      const SizedBox(height: 8),
                      for (final reward in page.items)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: HvpCard(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                  Row(children: <Widget>[
                                    Expanded(
                                        child: IconLabel(
                                            icon: HvpIcons.gift,
                                            iconSize: 18,
                                            label: reward.name,
                                            style: context.txt.titleS)),
                                    StatusChip(
                                        label: reward.isActive
                                            ? 'Đang bán'
                                            : 'Ngừng bán',
                                        icon: reward.isActive
                                            ? HvpIcons.storefront
                                            : HvpIcons.block,
                                        tone: reward.isActive
                                            ? ChipTone.success
                                            : ChipTone.neutral)
                                  ]),
                                  const SizedBox(height: 4),
                                  IconLabel(
                                      icon: HvpIcons.stock,
                                      label:
                                          '${reward.sku} · Tồn kho ${formatInt(reward.stock)}'),
                                  const SizedBox(height: 12),
                                  Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: <Widget>[
                                        HvpButton.primary(
                                            label: 'Nhập kho',
                                            icon: HvpIcons.stockIn,
                                            small: true,
                                            onPressed: () =>
                                                _adjust(reward, 'IN')),
                                        HvpButton.secondary(
                                            label: 'Xuất kho',
                                            icon: HvpIcons.stockOut,
                                            small: true,
                                            onPressed: () =>
                                                _adjust(reward, 'OUT')),
                                      ]),
                                ]))),
                      HvpPaginationBar(
                          page: page.page,
                          totalPages: page.totalPages,
                          onPageChanged: (value) =>
                              setState(() => _page = value)),
                    ]),
        ),
      )),
    ]);
  }
}

class _StockAdjustTab extends ConsumerStatefulWidget {
  const _StockAdjustTab({required this.reward, required this.movementType});
  final InventoryReward reward;
  final String movementType;

  @override
  ConsumerState<_StockAdjustTab> createState() => _StockAdjustTabState();
}

class _StockAdjustTabState extends ConsumerState<_StockAdjustTab> {
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  late final InventoryReward _reward = widget.reward;
  late String _movementType = widget.movementType;
  String? _formError;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reward = _reward;
    final quantity = int.tryParse(_quantity.text.trim());
    final reason = _reason.text.trim();
    if (quantity == null || quantity < 1) {
      setState(() => _formError = 'Số lượng phải là số nguyên lớn hơn 0.');
      return;
    }
    if (reason.length < 3) {
      setState(() => _formError = 'Nhập lý do ít nhất 3 ký tự.');
      return;
    }
    setState(() => _formError = null);
    final inbound = _movementType == 'IN';
    final success = await ref.read(inventoryAdjustProvider.notifier).run(
          () => ref.read(inventoryRepositoryProvider).adjust(
                rewardId: reward.id,
                movementType: _movementType,
                quantity: quantity,
                reason: reason,
              ),
        );
    if (!mounted || !success) return;
    setState(() {
      _quantity.clear();
      _reason.clear();
    });
    ref.invalidate(inventoryRewardsProvider);
    ref.invalidate(inventoryMovementsProvider);
    HvpToast.success(context,
        '${inbound ? 'Đã nhập' : 'Đã xuất'} $quantity · ${reward.name}.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final action = ref.watch(inventoryAdjustProvider);
    final reward = _reward;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, HvpLayout.navClearance),
      children: <Widget>[
        HvpCard(
          semanticLabel: 'Phần quà ${reward.name}, tồn kho ${reward.stock}',
          child: Row(
            children: <Widget>[
              Icon(HvpIcons.package, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(reward.name, style: t.titleS),
                    const SizedBox(height: 3),
                    IconLabel(
                      icon: HvpIcons.stock,
                      label:
                          '${reward.sku} · Tồn kho ${formatInt(reward.stock)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        IconLabel(
            icon: HvpIcons.adjust, label: 'Loại điều chỉnh', style: t.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            HvpFilterChip(
              label: 'Nhập kho',
              icon: HvpIcons.stockIn,
              selected: _movementType == 'IN',
              onSelected: () => setState(() => _movementType = 'IN'),
            ),
            HvpFilterChip(
              label: 'Xuất kho',
              icon: HvpIcons.stockOut,
              selected: _movementType == 'OUT',
              onSelected: () => setState(() => _movementType = 'OUT'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        HvpTextField(
          label: 'Số lượng',
          controller: _quantity,
          hint: 'Ví dụ: 10',
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly
          ],
          maxLength: 10,
        ),
        const SizedBox(height: 16),
        HvpTextField(
          label: 'Lý do',
          controller: _reason,
          hint: 'Ví dụ: Nhập hàng từ nhà cung cấp',
          maxLines: 2,
          maxLength: 500,
        ),
        if (_formError != null) ...<Widget>[
          const SizedBox(height: 12),
          InlineBanner(message: _formError!),
        ],
        if (action.error != null) ...<Widget>[
          const SizedBox(height: 12),
          InlineBanner(message: action.error!),
        ],
        const SizedBox(height: 20),
        HvpButton.primary(
          label:
              _movementType == 'IN' ? 'Xác nhận nhập kho' : 'Xác nhận xuất kho',
          icon: _movementType == 'IN' ? HvpIcons.stockIn : HvpIcons.stockOut,
          expand: true,
          loading: action.submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _StockHistoryTab extends ConsumerStatefulWidget {
  const _StockHistoryTab();

  @override
  ConsumerState<_StockHistoryTab> createState() => _StockHistoryTabState();
}

class _StockHistoryTabState extends ConsumerState<_StockHistoryTab> {
  String? _movementType;
  InventoryReward? _rewardFilter;
  int _page = 1;

  ({String? rewardId, String? movementType, int page}) get _filter =>
      (rewardId: _rewardFilter?.id, movementType: _movementType, page: _page);

  void _selectType(String? value) => setState(() {
        _movementType = value;
        _page = 1;
      });

  Future<void> _pickRewardFilter() async {
    final reward = await showHvpSheet<InventoryReward>(
      context,
      title: 'Lọc theo phần quà',
      builder: (_) => _RewardPickerSheet(selectedId: _rewardFilter?.id),
    );
    if (reward != null && mounted) {
      setState(() {
        _rewardFilter = reward;
        _page = 1;
      });
    }
  }

  void _clearRewardFilter() => setState(() {
        _rewardFilter = null;
        _page = 1;
      });

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final filter = _filter;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 64,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _filterChip(null, 'Tất cả', HvpIcons.all),
              _filterChip('IN', 'Nhập kho', HvpIcons.stockIn),
              _filterChip('OUT', 'Xuất kho', HvpIcons.stockOut),
              if (_rewardFilter == null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(HvpIcons.filter, size: 16),
                    label: const Text('Lọc theo quà'),
                    onPressed: _pickRewardFilter,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InputChip(
                    label: Text(_rewardFilter!.name),
                    onDeleted: _clearRewardFilter,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody<InventoryMovementPage>(
            value: ref.watch(inventoryMovementsProvider(filter)),
            onRetry: () => ref.invalidate(inventoryMovementsProvider(filter)),
            builder: (_, page) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(inventoryMovementsProvider(filter));
                await ref.read(inventoryMovementsProvider(filter).future);
              },
              child: page.items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const <Widget>[
                        SizedBox(
                          height: 360,
                          child: EmptyState(
                            icon: HvpIcons.package,
                            title: 'Chưa có điều chỉnh kho',
                            message:
                                'Các lượt nhập/xuất kho sẽ xuất hiện tại đây.',
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          16, 4, 16, HvpLayout.navClearance),
                      children: <Widget>[
                        Text(
                          '${page.total} lượt · Trang ${page.page}/${page.totalPages}',
                          style: t.caption,
                        ),
                        const SizedBox(height: 8),
                        for (final item in page.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MovementCard(item: item),
                          ),
                        HvpPaginationBar(
                          page: page.page,
                          totalPages: page.totalPages,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String? value, String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: HvpFilterChip(
          label: label,
          icon: icon,
          selected: _movementType == value,
          onSelected: () => _selectType(value),
        ),
      );
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.item});

  final InventoryMovement item;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return HvpCard(
      accent: item.isInbound ? context.hvp.emerald : context.hvp.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: IconLabel(
                      icon: HvpIcons.gift,
                      iconSize: 18,
                      label: item.rewardName,
                      style: t.titleS)),
              StatusChip(
                label: item.isInbound ? 'Nhập kho' : 'Xuất kho',
                tone: item.isInbound ? ChipTone.success : ChipTone.warning,
                icon: item.isInbound ? HvpIcons.stockIn : HvpIcons.stockOut,
              ),
            ],
          ),
          const SizedBox(height: 4),
          IconLabel(
            icon: HvpIcons.stock,
            label:
                '${item.rewardSku} · ${item.isInbound ? '+' : '-'}${formatInt(item.quantity)}',
          ),
          if (item.reason != null) ...<Widget>[
            const SizedBox(height: 3),
            IconLabel(icon: HvpIcons.note, label: item.reason!),
          ],
          const SizedBox(height: 3),
          IconLabel(
            icon: HvpIcons.user,
            label:
                '${item.actorName ?? 'Hệ thống'} · ${formatDateTime(item.createdAt)}',
            style: t.caption,
          ),
        ],
      ),
    );
  }
}

class _RewardPickerSheet extends ConsumerStatefulWidget {
  const _RewardPickerSheet({this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<_RewardPickerSheet> createState() => _RewardPickerSheetState();
}

class _RewardPickerSheetState extends ConsumerState<_RewardPickerSheet> {
  String _query = '';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final filter = (query: _query, page: _page);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: <Widget>[
            HvpTextField(
              label: 'Tìm phần quà',
              hint: 'Tên hoặc SKU',
              prefixIcon: HvpIcons.search,
              maxLength: 100,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => setState(() {
                _query = value.trim();
                _page = 1;
              }),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncBody<InventoryRewardPage>(
                value: ref.watch(inventoryRewardsProvider(filter)),
                onRetry: () => ref.invalidate(inventoryRewardsProvider(filter)),
                loading: const Center(child: CircularProgressIndicator()),
                builder: (_, page) => page.items.isEmpty
                    ? const EmptyState(
                        icon: HvpIcons.gift,
                        title: 'Không tìm thấy phần quà',
                        message: 'Thử tên hoặc SKU khác.',
                      )
                    : ListView(
                        children: <Widget>[
                          for (final reward in page.items)
                            Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(reward.name),
                                subtitle: Text(
                                  '${reward.sku} · Tồn ${formatInt(reward.stock)}'
                                  '${reward.isActive ? '' : ' · Ngừng bán'}',
                                ),
                                trailing: reward.id == widget.selectedId
                                    ? Icon(HvpIcons.checkCircle,
                                        color: context.hvp.gold)
                                    : null,
                                onTap: () => Navigator.of(context).pop(reward),
                              ),
                            ),
                          HvpPaginationBar(
                            page: page.page,
                            totalPages: page.totalPages,
                            onPageChanged: (value) =>
                                setState(() => _page = value),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
