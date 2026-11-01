import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../domain/schedule_query.dart';

/// "Tuần | Tháng" segmented control.
class ViewSwitch extends StatelessWidget {
  const ViewSwitch({super.key, required this.view, required this.onChanged});

  final ScheduleView view;
  final ValueChanged<ScheduleView> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return SegmentedButton<ScheduleView>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: c.goldSoft,
        selectedForegroundColor: c.gold,
        foregroundColor: c.textSecondary,
        side: BorderSide(color: c.border),
        textStyle: t.label,
      ),
      segments: const <ButtonSegment<ScheduleView>>[
        ButtonSegment<ScheduleView>(
            value: ScheduleView.week, label: Text('Tuần')),
        ButtonSegment<ScheduleView>(
            value: ScheduleView.month, label: Text('Tháng')),
      ],
      selected: <ScheduleView>{view},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
