import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../domain/schedule_dates.dart';
import '../../domain/schedule_models.dart';
import 'week_strip.dart';

/// Monday-first month grid. Days of neighbouring months are dimmed.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.items,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final List<ScheduleItem> items;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final c = context.hvp;
    final days = monthGrid(month);
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (var w = 1; w <= 7; w++)
              Expanded(
                child: Center(
                    child: Text(weekdayShort(w),
                        style: t.label.copyWith(color: c.textMuted))),
              ),
          ],
        ),
        for (var row = 0; row < days.length ~/ 7; row++)
          Row(
            children: <Widget>[
              for (final d in days.sublist(row * 7, row * 7 + 7))
                Expanded(
                  child: DayCell(
                    day: d,
                    dimmed: d.month != month.month,
                    statuses: statusesOn(items, d),
                    isToday: isoDay(d) == isoDay(today),
                    isSelected:
                        selected != null && isoDay(d) == isoDay(selected!),
                    // Neighbouring months are not loaded, so they are not selectable.
                    onTap: d.month != month.month ? () {} : () => onSelect(d),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
