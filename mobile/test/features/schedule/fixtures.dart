import 'package:hvp_forging/features/schedule/domain/schedule_models.dart';
import 'package:hvp_forging/features/schedule/domain/schedule_query.dart';
import 'package:hvp_forging/features/schedule/domain/schedule_repository.dart';

/// Wednesday 2026-03-04 (inside the week 02/03 - 08/03).
final DateTime fixtureToday = DateTime.utc(2026, 3, 4);

ScheduleItem sampleItem(
  String id, {
  String date = '2026-03-04',
  String? title = 'Boxing tối',
  SessionStatus status = SessionStatus.upcoming,
  bool isToday = false,
  bool isExam = false,
  String? coach = 'Nguyễn Văn A',
  String branch = 'HVP The Corner',
  int hour = 18,
}) =>
    ScheduleItem(
      sessionId: id,
      title: title,
      sessionType: SessionType.group,
      isExam: isExam,
      // 18:00 UTC+7 == 11:00 UTC
      startsAt: DateTime.utc(2026, 3, 4, hour - 7),
      endsAt: DateTime.utc(2026, 3, 4, hour - 7, 90),
      date: date,
      isToday: isToday,
      branchId: 'b1',
      branchName: branch,
      coachName: coach,
      status: status,
    );

/// Programmable [ScheduleRepository].
class FakeScheduleRepository implements ScheduleRepository {
  Future<ScheduleResult> Function(ScheduleQuery query) onSchedule =
      (_) async => const ScheduleResult(items: <ScheduleItem>[]);

  final List<ScheduleQuery> queries = <ScheduleQuery>[];

  @override
  Future<ScheduleResult> getSchedule(ScheduleQuery query) {
    queries.add(query);
    return onSchedule(query);
  }
}
