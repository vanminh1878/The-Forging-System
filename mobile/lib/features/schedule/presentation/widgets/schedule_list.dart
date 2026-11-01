import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/design/hvp_layout.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../domain/schedule_models.dart';
import 'session_card.dart';

/// Pull-to-refresh list of session cards under the calendar controls.
class ScheduleList extends StatelessWidget {
  const ScheduleList({
    super.key,
    required this.heading,
    required this.items,
    required this.onRefresh,
    this.onClearDay,
    this.clearDayLabel,
    this.onTapItem,
    this.emptyTitle = 'Không có buổi nào.',
    this.onEmptyAction,
  });

  final String heading;
  final List<ScheduleItem> items;
  final Future<void> Function() onRefresh;

  /// Shown under the heading when a single day is selected.
  final VoidCallback? onClearDay;
  final String? clearDayLabel;
  final ValueChanged<ScheduleItem>? onTapItem;

  /// Empty-state text; [onEmptyAction] adds a "Bỏ lọc" button (filtered empty).
  final String emptyTitle;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return HvpRefresh(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: HvpLayout.tabPagePadding,
        children: <Widget>[
          Text(heading.toUpperCase(), style: t.label),
          if (onClearDay != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onClearDay,
                child: Text('✕ ${clearDayLabel ?? 'Bỏ lọc'}',
                    style: t.label.copyWith(color: c.gold)),
              ),
            ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            SizedBox(
              height: 300,
              child: EmptyState(
                icon: HvpIcons.calendar,
                title: emptyTitle,
                actionLabel: onEmptyAction == null ? null : 'Bỏ lọc',
                onAction: onEmptyAction,
              ),
            )
          else
            for (final item in items) ...<Widget>[
              SessionCard(
                  item: item,
                  onTap: onTapItem == null ? null : () => onTapItem!(item)),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}
