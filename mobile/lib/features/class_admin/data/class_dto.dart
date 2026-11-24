import '../../../core/utils/json_utils.dart';
import '../domain/class_models.dart';

ClassSummary classSummaryFromJson(JsonMap j) => ClassSummary(
      id: str(j, 'id'),
      branchId: str(j, 'branchId'),
      name: str(j, 'name'),
      sessionTypeCode: str(j, 'sessionTypeCode'),
      courseId: strOrNull(j, 'courseId'),
      defaultCoachId: strOrNull(j, 'defaultCoachId'),
      weekdays: asList(j['weekdays'])
          .whereType<num>()
          .map((d) => d.toInt())
          .toList(growable: false),
      startTime: str(j, 'startTime'),
      durationMinutes: intOf(j, 'durationMinutes'),
      capacity: j['capacity'] == null ? null : intOf(j, 'capacity'),
      isActive: boolOf(j, 'isActive', true),
      enrolledCount: intOf(j, 'enrolledCount'),
    );

/// A row of `GET /coach/classes`: no capacity or course, and always an active class.
ClassSummary coachClassFromJson(JsonMap j) => ClassSummary(
      id: str(j, 'id'),
      branchId: str(asMap(j['branch']), 'id'),
      name: str(j, 'name'),
      sessionTypeCode: str(j, 'sessionType'),
      weekdays: asList(j['weekdays'])
          .whereType<num>()
          .map((d) => d.toInt())
          .toList(growable: false),
      startTime: str(j, 'startTime'),
      durationMinutes: intOf(j, 'durationMinutes'),
      isActive: true,
      enrolledCount: intOf(j, 'enrolledCount'),
    );

ClassDetail classDetailFromJson(JsonMap j) => ClassDetail(
      summary: classSummaryFromJson(j),
      roster: asList(j['roster'])
          .map((e) => asMap(e))
          .map((r) => RosterEntry(
                enrollmentId: str(r, 'enrollmentId'),
                memberId: str(r, 'memberId'),
                memberCode: str(r, 'memberCode'),
                fullName: str(r, 'fullName'),
              ))
          .toList(growable: false),
    );

ClassSession classSessionFromJson(JsonMap j) => ClassSession(
      id: str(j, 'id'),
      title: str(j, 'title'),
      startsAt: dateOrNull(j, 'startsAt') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: str(j, 'status'),
      isExam: boolOf(j, 'isExam'),
      attendeeCount: intOf(j, 'attendeeCount'),
      coachName: strOrNull(asMap(j['coach']), 'fullName'),
    );
