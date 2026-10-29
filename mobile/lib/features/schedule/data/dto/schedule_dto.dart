import '../../../../core/network/api_client.dart';
import '../../../../core/utils/json_utils.dart';
import '../../domain/schedule_models.dart';

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

ScheduleItem scheduleItemFromJson(JsonMap j) {
  final branch = asMap(j['branch']);
  final coach = asMap(j['coach']);
  return ScheduleItem(
    sessionId: str(j, 'sessionId'),
    classId: strOrNull(j, 'classId'),
    title: strOrNull(j, 'title'),
    sessionType: SessionType.parse(strOrNull(j, 'sessionType')),
    isExam: boolOf(j, 'isExam'),
    startsAt: dateOrNull(j, 'startsAt') ?? _epoch,
    endsAt: dateOrNull(j, 'endsAt') ?? _epoch,
    date: str(j, 'date'),
    isToday: boolOf(j, 'isToday'),
    branchId: strOrNull(branch, 'id'),
    branchName: str(branch, 'name'),
    coachName: strOrNull(coach, 'fullName'),
    status: SessionStatus.parse(strOrNull(j, 'status')),
    checkinAt: dateOrNull(j, 'checkinAt'),
    completionPercent:
        j['completionPercent'] == null ? null : intOf(j, 'completionPercent'),
  );
}

SessionDetail sessionDetailFromJson(JsonMap j) => SessionDetail(
      item: scheduleItemFromJson(j),
      lessonPlanTitle: strOrNull(asMap(j['lessonPlan']), 'title'),
      notes: strOrNull(j, 'notes'),
    );

ScheduleResult scheduleResultFromEnvelope(ApiEnvelope e) {
  final meta = asMap(e.meta);
  return ScheduleResult(
    items: e.dataList
        .map((x) => scheduleItemFromJson(asMap(x)))
        .toList(growable: false),
    from: strOrNull(meta, 'from'),
    to: strOrNull(meta, 'to'),
  );
}
