import 'package:flutter/material.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_filter_chip.dart';
import '../../domain/schedule_query.dart';

/// "Tuần | Tháng" choice.
class ViewSwitch extends StatelessWidget {
  const ViewSwitch({super.key, required this.view, required this.onChanged});

  final ScheduleView view;
  final ValueChanged<ScheduleView> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          HvpFilterChip(
            label: 'Tuần',
            icon: HvpIcons.weekView,
            selected: view == ScheduleView.week,
            onSelected: () => onChanged(ScheduleView.week),
          ),
          const SizedBox(width: 8),
          HvpFilterChip(
            label: 'Tháng',
            icon: HvpIcons.monthView,
            selected: view == ScheduleView.month,
            onSelected: () => onChanged(ScheduleView.month),
          ),
        ],
      );
}
