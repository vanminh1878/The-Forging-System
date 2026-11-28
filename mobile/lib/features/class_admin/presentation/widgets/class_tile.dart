import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch_providers.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/class_models.dart';
import '../../domain/class_rules.dart';
import '../../domain/session_types.dart';
import '../class_providers.dart';

/// One class in the list: name, schedule, branch, coach and enrolment.
class ClassTile extends ConsumerWidget {
  const ClassTile(
      {super.key,
      required this.item,
      this.onTap,
      this.onEdit,
      this.showCoach = true});

  final ClassSummary item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  /// Names the class's coach. Only admins may list staff, so other roles turn it off.
  final bool showCoach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.txt;
    final branch = ref
        .watch(branchesProvider)
        .valueOrNull
        ?.where((b) => b.id == item.branchId)
        .firstOrNull;
    final coach = showCoach
        ? ref
            .watch(classCoachesProvider)
            .valueOrNull
            ?.where((c) => c.id == item.defaultCoachId)
            .firstOrNull
        : null;
    return HvpCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(
                child: Text(item.name,
                    style: t.titleM,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
            if (onEdit != null)
              IconButton(
                  tooltip: 'Sửa lớp',
                  icon: const Icon(HvpIcons.pencil),
                  onPressed: onEdit),
            if (!item.isActive)
              const StatusChip(
                  label: 'Ngừng', tone: ChipTone.danger, icon: HvpIcons.block),
          ]),
          const SizedBox(height: 4),
          IconLabel(
              icon: HvpIcons.eventRepeat,
              label:
                  '${sessionTypeLabel(item.sessionTypeCode)} · ${weekdaysLabel(item.weekdays)} · ${item.startTime}',
              style: t.body),
          const SizedBox(height: 4),
          IconLabel(
              icon: HvpIcons.storefront,
              label: [
                if (branch != null) branch.name,
                if (coach != null) 'Coach ${coach.name}',
                '${enrolmentLabel(item.enrolledCount, item.capacity)} học viên',
              ].join(' · ')),
        ],
      ),
    );
  }
}
