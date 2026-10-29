import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../domain/schedule_dates.dart';
import '../../domain/schedule_models.dart';
import 'session_status_style.dart';

/// 7 day cells (T2..CN) with the day number and one dot per distinct status.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    required this.items,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> days;
  final List<ScheduleItem> items;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final d in days)
          Expanded(
            child: DayCell(
              day: d,
              statuses: statusesOn(items, d),
              isToday: isoDay(d) == isoDay(today),
              isSelected: selected != null && isoDay(d) == isoDay(selected!),
              showWeekday: true,
              onTap: () => onSelect(d),
            ),
          ),
      ],
    );
  }
}

/// Distinct statuses of the sessions on [day], in first-seen order.
List<SessionStatus> statusesOn(List<ScheduleItem> items, DateTime day) {
  final key = isoDay(day);
  final seen = <SessionStatus>[];
  for (final i in items) {
    if (i.date == key && !seen.contains(i.status)) seen.add(i.status);
  }
  return seen;
}

/// A day number with status dots. Today is gold, the selected day is `goldSoft`.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.statuses,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.showWeekday = false,
    this.dimmed = false,
  });

  final DateTime day;
  final List<SessionStatus> statuses;
  final bool isToday;
  final bool isSelected;
  final bool showWeekday;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final numberColor =
        isToday ? c.onGold : (dimmed ? c.textMuted : c.textPrimary);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showWeekday) ...<Widget>[
              Text(weekdayShort(day.weekday),
                  style: t.label.copyWith(color: c.textMuted)),
              const SizedBox(height: 4),
            ],
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? c.gold : (isSelected ? c.goldSoft : null),
                border: isSelected ? Border.all(color: c.gold) : null,
              ),
              child: Text('${day.day}',
                  style: t.titleS.copyWith(color: numberColor)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final s in statuses.take(3))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sessionStatusColor(c, s)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
