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
            child: Text(title, style: t.titleM, textAlign: TextAlign.center)),
        IconButton(
          tooltip: 'Sau',
          onPressed: onNext,
          icon: Icon(HvpIcons.caretRight, color: c.textPrimary),
        ),
        TextButton(
          onPressed: onToday,
          child: Text(todayLabel, style: t.label.copyWith(color: c.gold)),
        ),
      ],
    );
  }
}
