import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../domain/branch_admin_repository.dart';
import '../providers/branch_admin_providers.dart';
import '../widgets/branch_form_sheet.dart';

/// Admin "Danh sách chi nhánh".
class BranchListScreen extends ConsumerWidget {
  const BranchListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hvp;
    final t = context.txt;
    final showInactive = ref.watch(showInactiveBranchesProvider);
    final branches = ref.watch(adminBranchesProvider);

    Future<void> refresh() => ref.refresh(adminBranchesProvider.future);

    return Scaffold(
      appBar: const HvpAppBar(title: 'Chi nhánh', titleIcon: HvpIcons.mapPin),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: HvpButton.gold(
                label: 'Thêm chi nhánh',
                icon: HvpIcons.branchAdd,
                small: true,
                onPressed: () => _openForm(context),
              ),
            ),
          ),
          SwitchListTile(
            value: showInactive,
            onChanged: ref.read(showInactiveBranchesProvider.notifier).set,
            activeThumbColor: c.gold,
            title: Text('Hiện chi nhánh ngừng hoạt động', style: t.body),
          ),
          Expanded(
            child: AsyncBody<List<Branch>>(
              value: branches,
              onRetry: () => ref.invalidate(adminBranchesProvider),
              builder: (context, all) {
                final items = visibleBranches(all, showInactive: showInactive);
                return HvpRefresh(
                  onRefresh: refresh,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const <Widget>[
                            SizedBox(
                              height: 360,
                              child: EmptyState(
                                  icon: HvpIcons.mapPin,
                                  title: 'Chưa có chi nhánh nào.'),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _BranchCard(
                            branch: items[i],
                            onTap: () => _openForm(context, items[i]),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// BR-05: the add form, or the edit form when [branch] is given.
Future<void> _openForm(BuildContext context, [Branch? branch]) =>
    showHvpSheet<void>(
      context,
      title: branch == null ? 'Thêm chi nhánh' : 'Sửa chi nhánh',
      builder: (_) => BranchFormSheet(branch: branch),
    );

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch, required this.onTap});

  final Branch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final line = branch.addressLine;
    return HvpCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: IconLabel(
                      icon: HvpIcons.storefront,
                      iconSize: 18,
                      label: branch.name,
                      style: t.titleS)),
              const SizedBox(width: 8),
              StatusChip(
                label: branch.isActive ? 'Đang hoạt động' : 'Ngừng hoạt động',
                icon: branch.isActive ? HvpIcons.checkCircle : HvpIcons.block,
                tone: branch.isActive ? ChipTone.success : ChipTone.neutral,
              ),
            ],
          ),
          if (line.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            IconLabel(icon: HvpIcons.mapPin, label: line)
          ],
        ],
      ),
    );
  }
}
