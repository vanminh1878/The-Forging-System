import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/branch_admin_repository.dart';
import '../providers/branch_admin_providers.dart';

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
      appBar: const HvpAppBar(title: 'Chi nhánh'),
      body: Column(
        children: <Widget>[
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
                          itemBuilder: (_, i) => _BranchCard(branch: items[i]),
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

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final line = branch.addressLine;
    return HvpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(branch.name, style: t.titleS)),
              const SizedBox(width: 8),
              StatusChip(
                label: branch.isActive ? 'Đang hoạt động' : 'Ngừng hoạt động',
                tone: branch.isActive ? ChipTone.success : ChipTone.neutral,
              ),
            ],
          ),
          if (line.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(line, style: t.bodySmall)
          ],
          if (branch.qrVersion != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('Mã QR: phiên bản ${branch.qrVersion}', style: t.caption),
          ],
        ],
      ),
    );
  }
}
