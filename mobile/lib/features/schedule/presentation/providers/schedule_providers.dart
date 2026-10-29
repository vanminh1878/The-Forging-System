import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/schedule_api.dart';
import '../../data/schedule_repository_impl.dart';
import '../../domain/schedule_dates.dart';
import '../../domain/schedule_models.dart';
import '../../domain/schedule_query.dart';
import '../../domain/schedule_repository.dart';

/// Tests override this with a fake repository.
final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepositoryImpl(ScheduleApi(ref.watch(apiClientProvider))),
);

/// Today in Vietnam (date-only). Tests override it for a fixed calendar.
final scheduleTodayProvider =
    Provider<DateTime>((ref) => dateOnly(toVietnamTime(DateTime.now())));

/// What the schedule tab is looking at. Starts on the current week, unfiltered.
class ScheduleQueryNotifier extends Notifier<ScheduleQuery> {
  @override
  ScheduleQuery build() {
    ref.watch(currentUserIdProvider); // a new account starts fresh
    return ScheduleQuery(
        view: ScheduleView.week, anchorDate: ref.read(scheduleTodayProvider));
  }

  /// Previous (-1) or next (+1) week or month, depending on the view.
  void shift(int delta) => state = state.copyWith(
        anchorDate: state.view == ScheduleView.week
            ? shiftWeeks(state.anchorDate, delta)
            : shiftMonths(state.anchorDate, delta),
      );

  /// null = all branches. Kept when paging or switching view.
  void setBranch(String? id) => state = id == null
      ? state.copyWith(clearBranch: true)
      : state.copyWith(branchId: id);

  /// null = all statuses.
  void setStatus(SessionStatus? status) => state = status == null
      ? state.copyWith(clearStatus: true)
      : state.copyWith(status: status);

  void clearFilters() =>
      state = state.copyWith(clearBranch: true, clearStatus: true);

  void setView(ScheduleView view) => state = state.copyWith(view: view);

  void goToday() =>
      state = state.copyWith(anchorDate: ref.read(scheduleTodayProvider));
}

final scheduleQueryProvider =
    NotifierProvider<ScheduleQueryNotifier, ScheduleQuery>(
        ScheduleQueryNotifier.new);

/// Sessions for the current query.
final scheduleProvider = FutureProvider.autoDispose<ScheduleResult>((ref) {
  ref.watch(currentUserIdProvider);
  final query = ref.watch(scheduleQueryProvider);
  return ref.watch(scheduleRepositoryProvider).getSchedule(query);
});

/// Day picked in the week strip (null = whole week). Resets when the period changes.
class SelectedDayNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    ref.watch(scheduleQueryProvider
        .select((q) => '${q.view.wire}${isoDay(q.anchorDate)}'));
    return null;
  }

  void select(DateTime? day) => state = day;
}

final selectedDayProvider =
    NotifierProvider<SelectedDayNotifier, DateTime?>(SelectedDayNotifier.new);
