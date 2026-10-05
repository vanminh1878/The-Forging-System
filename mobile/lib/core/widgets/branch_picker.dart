import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../branch/branch.dart';
import '../branch/branch_providers.dart';
import '../design/chamfer_border.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import 'hvp_bottom_sheet.dart';

/// Field that opens a sheet listing the active branches.
class BranchPicker extends ConsumerWidget {
  const BranchPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
    this.label = 'Chi nhánh',
    this.allowAll = false,
  });

  final String? selectedId;
  final ValueChanged<Branch?> onChanged;
  final String label;

  /// Adds an "all branches" row that reports null.
  final bool allowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hvp;
    final t = context.txt;
    final branches = ref.watch(branchesProvider);
    final list = branches.valueOrNull ?? const <Branch>[];
    Branch? selected;
    for (final b in list) {
      if (b.id == selectedId) selected = b;
    }
    final text = branches.isLoading && list.isEmpty
        ? 'Đang tải...'
        : (selected?.name ?? (allowAll ? 'Tất cả chi nhánh' : 'Chọn chi nhánh'));
    final shape = ChamferBorder(cut: 8, side: BorderSide(color: c.border));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: t.label),
        const SizedBox(height: 6),
        Material(
          color: c.surfaceHigh,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: list.isEmpty
                ? () => ref.invalidate(branchesProvider)
                : () async {
                    final picked = await showOptionSheet<String>(
                      context,
                      title: label,
                      selected: selectedId ?? '',
                      options: <SheetOption<String>>[
                        if (allowAll) const SheetOption<String>(value: '', label: 'Tất cả chi nhánh', icon: HvpIcons.mapPin),
                        for (final b in list)
                          SheetOption<String>(value: b.id, label: b.name, subtitle: b.address, icon: HvpIcons.mapPin),
                      ],
                    );
                    if (picked == null) return;
                    if (picked.isEmpty) {
                      onChanged(null);
                      return;
                    }
                    onChanged(list.firstWhere((b) => b.id == picked));
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(HvpIcons.mapPin, size: 20, color: c.textMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: t.bodyL)),
                  Icon(HvpIcons.caretDown, size: 18, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
