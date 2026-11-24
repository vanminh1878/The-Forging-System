import 'class_models.dart';

abstract interface class ClassRepository {
  Future<ClassPage> list(ClassQuery query);

  /// `GET /coach/classes`: the active classes whose default coach is the signed-in coach.
  Future<List<ClassSummary>> coachClasses();

  Future<ClassSummary> create(ClassDraft draft);

  /// [changes] holds only the edited fields (see [ClassDraft.changesFrom]).
  Future<ClassSummary> update(String id, Map<String, Object?> changes);

  Future<ClassDetail> detail(String id);

  /// Enrols [memberId] (a `user_id`) from today.
  Future<void> enrol(String classId, String memberId);

  /// Ends the member's enrolment; the row is kept as ENDED on the server.
  Future<void> removeMember(String classId, String memberId);

  /// Sessions from today for the next 28 days (the API default).
  Future<List<ClassSession>> sessions(String classId);

  Future<void> cancelSession(String sessionId, String reason);

  Future<void> createSession(SessionDraft draft);

  /// Exam session of a class on [date] (`YYYY-MM-DD`, local); [title] defaults on the server.
  Future<void> createExamSession(String classId, String date, {String? title});

  /// Coaches and head coaches, for pickers and for naming a class's coach.
  Future<List<ClassCoach>> coaches();
}
