import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../domain/membership_rules.dart';
import '../../domain/package_class_option.dart';
import '../providers/membership_providers.dart';

/// "Choose a class" list of a package (student request, reception activation
/// and approval). Full classes are shown but cannot be picked.
class PackageClassPicker extends ConsumerWidget {
  const PackageClassPicker({
    super.key,
    required this.packageTypeId,
    required this.selectedId,
    required this.onChanged,
    this.enabled = true,
    this.memberId,
  });

  final String packageTypeId;
  final String? selectedId;
  final ValueChanged<PackageClassOption> onChanged;
  final bool enabled;

  /// Staff only: the learner whose seats decide `enrolled`.
  final String? memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (packageTypeId: packageTypeId, memberId: memberId);
    return AsyncBody<List<PackageClassOption>>(
      value: ref.watch(packageClassesProvider(key)),
      onRetry: () => ref.invalidate(packageClassesProvider(key)),
      loading: const SizedBox(height: 200, child: ShimmerList(itemCount: 2)),
      builder: (context, classes) {
        if (classes.isEmpty) {
          return const EmptyState(
            icon: HvpIcons.calendar,
            title: 'Gói này chưa có lớp nào đang mở',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final c in classes) ...<Widget>[
              _ClassTile(
                option: c,
                selected: c.id == selectedId,
                onTap: enabled && c.isSelectable ? () => onChanged(c) : null,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile(
      {required this.option, required this.selected, required this.onTap});

  final PackageClassOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return Opacity(
      opacity: option.isSelectable ? 1 : 0.5,
      child: HvpCard(
        accent: selected ? c.gold : null,
        highlighted: selected,
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(option.name, style: t.titleS),
                  const SizedBox(height: 2),
                  Text(classPlaceLabel(option), style: t.bodySmall),
                  Text(
                      classScheduleLabel(option.weekdays, option.startTime,
                          option.durationMinutes),
                      style: t.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                      option.enrolled
                          ? enrolledClassLabel
                          : seatsLabel(option.seatsLeft),
                      style: t.label.copyWith(
                          color: option.enrolled
                              ? c.gold
                              : (option.isFull ? c.red : c.textMuted))),
                ],
              ),
            ),
            if (selected) Icon(HvpIcons.checkCircle, color: c.gold),
          ],
        ),
      ),
    );
  }
}
