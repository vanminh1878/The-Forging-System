/// Learner schedule entities (`GET /me/schedule`).
library;

/// Derived session status, with the Vietnamese label shown to members.
enum SessionStatus {
  upcoming('UPCOMING', 'Sắp tới', 'Sắp diễn ra'),
  awaitingCoach('AWAITING_COACH', 'Chờ coach xác nhận', 'Chờ Coach xác nhận'),
  confirmedPass('CONFIRMED_PASS', 'Đạt', 'Đã hoàn thành'),
  confirmedFail('CONFIRMED_FAIL', 'Chưa đạt', 'Chưa đạt ngưỡng'),
  absent('ABSENT', 'Vắng mặt', 'Không tham gia'),
  cancelled('CANCELLED', 'Đã huỷ', 'Buổi tập đã bị huỷ');

  const SessionStatus(this.wire, this.label, this.description);

  /// Value of the `status` query parameter / response field.
  final String wire;
  final String label;

  /// Longer sentence used on the session detail screen.
  final String description;

  static SessionStatus parse(String? value) {
    for (final s in SessionStatus.values) {
      if (s.wire == value) return s;
    }
    return SessionStatus.upcoming;
  }

  bool get isConfirmed => this == confirmedPass || this == confirmedFail;
}

enum SessionType {
  group('GROUP', 'Lớp nhóm'),
  pt('PT', 'PT 1-1'),
  academy('ACADEMY', 'Academy'),
  workshop('WORKSHOP', 'Workshop'),
  sparring('SPARRING', 'Sparring');

  const SessionType(this.wire, this.label);

  final String wire;
  final String label;

  static SessionType parse(String? value) {
    for (final s in SessionType.values) {
      if (s.wire == value) return s;
    }
    return SessionType.group;
  }
}

/// One session on the learner's calendar.
class ScheduleItem {
  const ScheduleItem({
    required this.sessionId,
    required this.sessionType,
    required this.isExam,
    required this.startsAt,
    required this.endsAt,
    required this.date,
    required this.isToday,
    required this.branchName,
    required this.status,
    this.classId,
    this.title,
    this.branchId,
    this.coachName,
    this.checkinAt,
    this.completionPercent,
  });

  final String sessionId;
  final String? classId;
  final String? title;
  final SessionType sessionType;
  final bool isExam;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Local calendar day (`YYYY-MM-DD`), as sent by the API.
  final String date;
  final bool isToday;
  final String? branchId;
  final String branchName;
  final String? coachName;
  final SessionStatus status;
  final DateTime? checkinAt;
  final int? completionPercent;

  /// Title shown on cards: exam prefix, falling back to the session type.
  String get displayTitle =>
      '${isExam ? '📝 ' : ''}${title ?? sessionType.label}';
}

/// `GET /me/sessions/:id`: the calendar item plus lesson plan and notes.
class SessionDetail {
  const SessionDetail({required this.item, this.lessonPlanTitle, this.notes});

  final ScheduleItem item;
  final String? lessonPlanTitle;
  final String? notes;
}

/// A schedule response: items plus the covered range (`meta.from` / `meta.to`).
class ScheduleResult {
  const ScheduleResult({required this.items, this.from, this.to});

  final List<ScheduleItem> items;
  final String? from;
  final String? to;
}
