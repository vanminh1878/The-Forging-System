import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_body.dart';
import '../../domain/schedule_dates.dart';
import '../../domain/schedule_models.dart';
import '../../domain/schedule_query.dart';
import '../providers/schedule_providers.dart';
import '../widgets/month_grid.dart';
import '../widgets/period_header.dart';
import '../widgets/schedule_list.dart';
import '../widgets/view_switch.dart';
import '../widgets/week_strip.dart';

/// "Lịch tập" tab of the student shell (body only; the shell provides the app bar).
class ScheduleTab extends ConsumerWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(scheduleQueryProvider);
    final notifier = ref.read(scheduleQueryProvider.notifier);
    final async = ref.watch(scheduleProvider);
    final today = ref.watch(scheduleTodayProvider);
    final selected = ref.watch(selectedDayProvider);
    final select = ref.read(selectedDayProvider.notifier).select;
    final all = async.valueOrNull?.items ?? const <ScheduleItem>[];
    final isWeek = query.view == ScheduleView.week;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: <Widget>[
              ViewSwitch(view: query.view, onChanged: notifier.setView),
              PeriodHeader(
                title: isWeek
                    ? weekRangeLabel(query.anchorDate)
                    : monthLabel(query.anchorDate),
                todayLabel: isWeek ? 'Tuần này' : 'Tháng này',
                onPrev: () => notifier.shift(-1),
                onNext: () => notifier.shift(1),
                onToday: notifier.goToday,
              ),
              if (isWeek)
                WeekStrip(
                  days: weekDays(query.anchorDate),
                  items: all,
                  today: today,
                  selected: selected,
                  onSelect: select,
                )
              else
                MonthGrid(
                  month: query.anchorDate,
                  items: all,
                  today: today,
                  selected: selected,
                  onSelect: select,
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody<ScheduleResult>(
            value: async,
            onRetry: () => ref.invalidate(scheduleProvider),
            builder: (context, result) {
              final items = selected == null
                  ? result.items
                  : result.items
                      .where((i) => i.date == isoDay(selected))
                      .toList(growable: false);
              return ScheduleList(
                heading: _heading(isWeek, selected),
                items: items,
                onRefresh: () => ref.refresh(scheduleProvider.future),
                onClearDay: selected == null ? null : () => select(null),
                clearDayLabel:
                    isWeek ? 'Bỏ lọc, xem cả tuần' : 'Bỏ lọc, xem cả tháng',
              );
            },
          ),
        ),
      ],
    );
  }

  static String _heading(bool isWeek, DateTime? day) {
    if (day == null) {
      return isWeek ? 'Tất cả buổi tập tuần này' : 'Tất cả buổi tập tháng này';
    }
    final label = isWeek
        ? weekdayLong(day.weekday)
        : '${weekdayLong(day.weekday)} ${formatDayMonth(day)}';
    return '$label — buổi trong ngày';
  }
}
