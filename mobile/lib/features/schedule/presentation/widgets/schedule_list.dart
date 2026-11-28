import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/design/hvp_layout.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../domain/schedule_models.dart';
import 'session_card.dart';

/// Pull-to-refresh list of session cards. The calendar controls ([header]) are
/// the first rows of the same scrollable, so a tall month grid scrolls away
/// instead of squeezing the list into the space left above the bottom bar.
class ScheduleList extends StatelessWidget {
  const ScheduleList({
    super.key,
    this.header,
    this.state,
    this.heading = '',
    this.items = const <ScheduleItem>[],
    required this.onRefresh,
    this.onClearDay,
    this.clearDayLabel,
    this.onTapItem,
    this.emptyTitle = 'Không có buổi nào.',
    this.onEmptyAction,
  });

  /// Calendar controls shown above the sessions.
  final Widget? header;

  /// Replaces the sessions while loading or after an error.
  final Widget? state;
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
          if (header != null) header!,
          if (state != null)
            state!
          else ...<Widget>[
            IconLabel(
                icon: HvpIcons.list,
                label: heading.toUpperCase(),
                style: t.label),
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
              // No fixed height: in a list it takes what it needs.
              EmptyState(
                icon: HvpIcons.calendar,
                title: emptyTitle,
                actionLabel: onEmptyAction == null ? null : 'Bỏ lọc',
                onAction: onEmptyAction,
              )
            else
              for (final item in items) ...<Widget>[
                SessionCard(
                    item: item,
                    onTap: onTapItem == null ? null : () => onTapItem!(item)),
                const SizedBox(height: 12),
              ],
          ],
        ],
      ),
    );
  }
}
