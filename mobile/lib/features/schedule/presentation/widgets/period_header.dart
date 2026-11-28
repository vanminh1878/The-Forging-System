import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';

/// "‹ title ›" pager with a "go to now" button.
class PeriodHeader extends StatelessWidget {
  const PeriodHeader({
    super.key,
    required this.title,
    required this.todayLabel,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final String title;
  final String todayLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Trước',
          onPressed: onPrev,
          icon: Icon(HvpIcons.caretLeft, color: c.textPrimary),
        ),
        Expanded(
          // The range shrinks on a narrow phone instead of losing its end.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(HvpIcons.dateRange, size: 18, color: c.gold),
                const SizedBox(width: 6),
                Text(title, style: t.titleM, maxLines: 1),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Sau',
          onPressed: onNext,
          icon: Icon(HvpIcons.caretRight, color: c.textPrimary),
        ),
        TextButton(
          onPressed: onToday,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(HvpIcons.calendarCheck, size: 16, color: c.gold),
              const SizedBox(width: 4),
              Text(todayLabel, style: t.label.copyWith(color: c.gold)),
            ],
          ),
        ),
      ],
    );
  }
}
