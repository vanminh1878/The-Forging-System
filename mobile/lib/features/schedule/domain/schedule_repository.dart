import 'schedule_models.dart';
import 'schedule_query.dart';

/// What the schedule screens need from the backend.
abstract class ScheduleRepository {
  /// `GET /me/schedule?view&date&branchId&status`
  Future<ScheduleResult> getSchedule(ScheduleQuery query);

  /// `GET /me/sessions/:id`. Throws `ApiException` with `statusCode` 404 when the
  /// session is not on this learner's calendar.
  Future<SessionDetail> getSession(String sessionId);
}
