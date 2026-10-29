import 'schedule_dates.dart';
import 'schedule_models.dart';

enum ScheduleView {
  week('week'),
  month('month');

  const ScheduleView(this.wire);

  final String wire;
}

/// What the schedule screen is showing. [anchorDate] is any day of the period.
class ScheduleQuery {
  const ScheduleQuery({
    required this.view,
    required this.anchorDate,
    this.branchId,
    this.status,
  });

  final ScheduleView view;
  final DateTime anchorDate;
  final String? branchId;
  final SessionStatus? status;

  bool get hasFilter => branchId != null || status != null;

  ScheduleQuery copyWith({
    ScheduleView? view,
    DateTime? anchorDate,
    String? branchId,
    SessionStatus? status,
    bool clearBranch = false,
    bool clearStatus = false,
  }) =>
      ScheduleQuery(
        view: view ?? this.view,
        anchorDate: anchorDate ?? this.anchorDate,
        branchId: clearBranch ? null : (branchId ?? this.branchId),
        status: clearStatus ? null : (status ?? this.status),
      );

  @override
  bool operator ==(Object other) =>
      other is ScheduleQuery &&
      other.view == view &&
      isoDay(other.anchorDate) == isoDay(anchorDate) &&
      other.branchId == branchId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(view, isoDay(anchorDate), branchId, status);
}
