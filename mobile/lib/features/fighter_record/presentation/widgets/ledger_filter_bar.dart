import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_filter_chip.dart';
import '../../domain/points_models.dart';
import '../providers/fighter_record_providers.dart';
import 'point_source_style.dart';

/// Horizontal filter chips: "Tất cả" + every ledger source.
class LedgerFilterBar extends ConsumerWidget {
  const LedgerFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(ledgerFilterProvider);
    final notifier = ref.read(ledgerFilterProvider.notifier);
    final options = <PointSource?>[null, ...PointSource.filterable];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          return HvpFilterChip(
            label: (option == null ? 'Tất cả' : option.label).toUpperCase(),
            icon: option == null ? HvpIcons.all : iconOfSource(option),
            selected: option == selected,
            onSelected: () => notifier.select(option),
          );
        },
      ),
    );
  }
}
