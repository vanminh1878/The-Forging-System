import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../domain/schedule_dates.dart';
import '../../domain/schedule_models.dart';
import '../../domain/schedule_query.dart';
import '../providers/schedule_providers.dart';
import '../widgets/filter_bar.dart';
import '../widgets/month_grid.dart';
import '../widgets/period_header.dart';
import '../widgets/schedule_list.dart';
import '../widgets/view_switch.dart';
import '../widgets/week_strip.dart';

/// "Lịch tập" tab of the student shell (body only; the shell provides the app bar).
///
/// The controls, the calendar and the sessions are one scrollable page: the
/// month grid is tall, and the floating bottom bar covers the lower part of the
/// screen, so a fixed grid would leave almost no room for the list.
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

    final controls = Column(
      children: <Widget>[
        ViewSwitch(view: query.view, onChanged: notifier.setView),
        FilterBar(
          branchId: query.branchId,
          status: query.status,
          onBranch: notifier.setBranch,
          onStatus: notifier.setStatus,
        ),
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
        const SizedBox(height: 12),
      ],
    );

    Future<void> refresh() => ref.refresh(scheduleProvider.future);

    return async.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => ScheduleList(
        header: controls,
        state: const SizedBox(height: 360, child: ShimmerList()),
        onRefresh: refresh,
      ),
      error: (error, _) => ScheduleList(
        header: controls,
        state: SizedBox(
          height: 360,
          child: ErrorState.fromError(error,
              onRetry: () => ref.invalidate(scheduleProvider)),
        ),
        onRefresh: refresh,
      ),
      data: (result) {
        final items = selected == null
            ? result.items
            : result.items
                .where((i) => i.date == isoDay(selected))
                .toList(growable: false);
        final filtered = query.hasFilter && items.isEmpty;
        return ScheduleList(
          header: controls,
          heading: _heading(isWeek, selected),
          items: items,
          onTapItem: (i) => context.push(StudentPaths.session(i.sessionId)),
          emptyTitle: filtered
              ? 'Không có buổi nào khớp bộ lọc.'
              : 'Không có buổi nào.',
          onEmptyAction: filtered ? notifier.clearFilters : null,
          onRefresh: refresh,
          onClearDay: selected == null ? null : () => select(null),
          clearDayLabel:
              isWeek ? 'Bỏ lọc, xem cả tuần' : 'Bỏ lọc, xem cả tháng',
        );
      },
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
