import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_body.dart';
import '../../domain/schedule_dates.dart';
import '../../domain/schedule_models.dart';
import '../providers/schedule_providers.dart';
import '../widgets/period_header.dart';
import '../widgets/schedule_list.dart';
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
    final all = async.valueOrNull?.items ?? const <ScheduleItem>[];

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: <Widget>[
              PeriodHeader(
                title: weekRangeLabel(query.anchorDate),
                todayLabel: 'Tuần này',
                onPrev: () => notifier.shiftWeek(-1),
                onNext: () => notifier.shiftWeek(1),
                onToday: notifier.goToday,
              ),
              WeekStrip(
                days: weekDays(query.anchorDate),
                items: all,
                today: today,
                selected: selected,
                onSelect: ref.read(selectedDayProvider.notifier).select,
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
                heading: selected == null
                    ? 'Tất cả buổi tập tuần này'
                    : '${weekdayLong(selected.weekday)} — buổi trong ngày',
                items: items,
                onRefresh: () => ref.refresh(scheduleProvider.future),
                onClearDay: selected == null
                    ? null
                    : () => ref.read(selectedDayProvider.notifier).select(null),
                clearDayLabel: 'Bỏ lọc, xem cả tuần',
              );
            },
          ),
        ),
      ],
    );
  }
}
