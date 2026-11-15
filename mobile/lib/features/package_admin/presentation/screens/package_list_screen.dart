import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../membership/domain/membership_models.dart';
import '../../../membership/domain/membership_rules.dart';
import '../../domain/package_rules.dart';
import '../providers/package_admin_providers.dart';
import '../widgets/package_form_sheet.dart';

/// PKG-06: admin "Gói tập" list with create / edit.
class PackageListScreen extends ConsumerWidget {
  const PackageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: HvpAppBar(title: 'Gói tập', actions: <Widget>[
        IconButton(
          tooltip: 'Thêm gói',
          icon: const Icon(HvpIcons.plus),
          onPressed: () => showPackageForm(context),
        ),
      ]),
      body: AsyncBody<List<PackageType>>(
        value: ref.watch(adminPackagesProvider),
        onRetry: () => ref.invalidate(adminPackagesProvider),
        builder: (context, items) => HvpRefresh(
          onRefresh: () => ref.refresh(adminPackagesProvider.future),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const <Widget>[
                    SizedBox(
                      height: 360,
                      child: EmptyState(
                          icon: HvpIcons.ticket, title: 'Chưa có gói tập nào'),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _PackageCard(
                    package: items[i],
                    onTap: () => showPackageForm(context, existing: items[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.onTap});

  final PackageType package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return HvpCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(package.name, style: t.titleS)),
            if (!package.isActive)
              const StatusChip(label: 'Ngừng bán', tone: ChipTone.danger),
          ]),
          const SizedBox(height: 4),
          Text(priceLabel(package.priceVnd),
              style: t.titleS.copyWith(color: c.gold)),
          const SizedBox(height: 2),
          Text(packageSummary(package), style: t.bodySmall),
          const SizedBox(height: 2),
          Text(
              '${package.code} · ${classCountLabel(package.classCount)}'
              '${package.isTrial ? ' · Gói trải nghiệm' : ''}',
              style: t.caption),
        ],
      ),
    );
  }
}
