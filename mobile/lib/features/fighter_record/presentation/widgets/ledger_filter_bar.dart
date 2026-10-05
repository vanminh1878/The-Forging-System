import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../domain/points_models.dart';
import '../providers/fighter_record_providers.dart';

/// Horizontal filter chips: "Tất cả" + every ledger source.
class LedgerFilterBar extends ConsumerWidget {
  const LedgerFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(ledgerFilterProvider);
    final notifier = ref.read(ledgerFilterProvider.notifier);
    final options = <PointSource?>[null, ...PointSource.filterable];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          return _FilterChip(
            label: option == null ? 'Tất cả' : option.label,
            selected: option == selected,
            onTap: () => notifier.select(option),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return ChoiceChip(
      label: Text(label.toUpperCase()),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: t.titleS.copyWith(color: selected ? c.onGold : c.textSecondary, fontSize: 12),
      selectedColor: c.gold,
      backgroundColor: c.surfaceHigh,
      side: BorderSide(color: selected ? c.gold : c.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}
