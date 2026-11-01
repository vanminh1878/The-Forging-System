import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch.dart';
import '../../../../core/branch/branch_providers.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../domain/schedule_models.dart';

/// Branch + status filter chips shared by the week and month views.
class FilterBar extends ConsumerWidget {
  const FilterBar({
    super.key,
    required this.branchId,
    required this.status,
    required this.onBranch,
    required this.onStatus,
  });

  final String? branchId;
  final SessionStatus? status;
  final ValueChanged<String?> onBranch;
  final ValueChanged<SessionStatus?> onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches =
        ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    String? branchName;
    for (final b in branches) {
      if (b.id == branchId) branchName = b.name;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _FilterChip(
              icon: HvpIcons.mapPin,
              label: branchId == null
                  ? 'Tất cả chi nhánh'
                  : (branchName ?? 'Chi nhánh'),
              active: branchId != null,
              onTap: () async {
                if (branches.isEmpty) {
                  ref.invalidate(branchesProvider);
                  return;
                }
                final picked = await showOptionSheet<String>(
                  context,
                  title: 'Chi nhánh',
                  selected: branchId ?? '',
                  options: <SheetOption<String>>[
                    const SheetOption<String>(
                        value: '',
                        label: 'Tất cả chi nhánh',
                        icon: HvpIcons.mapPin),
                    for (final b in branches)
                      SheetOption<String>(
                          value: b.id,
                          label: b.name,
                          subtitle: b.address,
                          icon: HvpIcons.mapPin),
                  ],
                );
                if (picked != null) {
                  onBranch(picked.isEmpty ? null : picked);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChip(
              icon: HvpIcons.list,
              label: status?.label ?? 'Tất cả trạng thái',
              active: status != null,
              onTap: () async {
                final picked = await showOptionSheet<String>(
                  context,
                  title: 'Trạng thái',
                  selected: status?.wire ?? '',
                  options: <SheetOption<String>>[
                    const SheetOption<String>(
                        value: '', label: 'Tất cả trạng thái'),
                    for (final s in SessionStatus.values)
                      SheetOption<String>(value: s.wire, label: s.label),
                  ],
                );
                if (picked != null) {
                  onStatus(picked.isEmpty ? null : SessionStatus.parse(picked));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final color = active ? c.gold : c.textSecondary;
    return Material(
      color: active ? c.goldSoft : c.surfaceHigh,
      shape: StadiumBorder(side: BorderSide(color: active ? c.gold : c.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(label,
                      style: t.bodySmall.copyWith(color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Icon(HvpIcons.caretDown, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
