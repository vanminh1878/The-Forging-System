import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/class_models.dart';
import '../domain/class_repository.dart';
import 'class_dto.dart';

class ClassRepositoryImpl implements ClassRepository {
  ClassRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<ClassPage> list(ClassQuery query) async {
    final response = await _api.get('/admin/classes', query: <String, dynamic>{
      'page': query.page,
      'limit': query.limit,
      if (query.sessionTypeCode != null)
        'sessionTypeCode': query.sessionTypeCode,
    });
    final meta = PageMeta.fromJson(response.meta, fallbackLimit: query.limit);
    return ClassPage(
      items: response.dataList
          .map((e) => classSummaryFromJson(asMap(e)))
          .toList(growable: false),
      page: meta.page,
      total: meta.total,
      totalPages: meta.totalPages,
    );
  }

  @override
  Future<List<ClassSummary>> coachClasses() async {
    final response = await _api.get('/coach/classes');
    return response.dataList
        .map((e) => coachClassFromJson(asMap(e)))
        .toList(growable: false);
  }

  @override
  Future<ClassSummary> create(ClassDraft draft) async => classSummaryFromJson(
      (await _api.post('/admin/classes', body: draft.toJson())).dataMap);

  @override
  Future<ClassSummary> update(String id, Map<String, Object?> changes) async =>
      classSummaryFromJson(
          (await _api.patch('/admin/classes/$id', body: changes)).dataMap);

  @override
  Future<ClassDetail> detail(String id) async =>
      classDetailFromJson((await _api.get('/admin/classes/$id')).dataMap);

  @override
  Future<void> enrol(String classId, String memberId) async {
    await _api.post('/admin/classes/$classId/enrollments',
        body: <String, dynamic>{'memberId': memberId});
  }

  @override
  Future<void> removeMember(String classId, String memberId) async {
    await _api.delete('/admin/classes/$classId/enrollments/$memberId');
  }

  @override
  Future<List<ClassSession>> sessions(String classId) async {
    final response = await _api.get('/admin/classes/$classId/sessions');
    return response.dataList
        .map((e) => classSessionFromJson(asMap(e)))
        .toList(growable: false);
  }

  @override
  Future<void> cancelSession(String sessionId, String reason) async {
    await _api.post('/sessions/$sessionId/cancel',
        body: <String, dynamic>{'reason': reason.trim()});
  }

  @override
  Future<void> createSession(SessionDraft draft) async {
    await _api.post('/sessions', body: draft.toJson());
  }

  @override
  Future<void> createExamSession(String classId, String date,
      {String? title}) async {
    await _api.post('/classes/$classId/exam-sessions', body: <String, dynamic>{
      'date': date,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
    });
  }

  @override
  Future<List<ClassCoach>> coaches() async {
    final result = <ClassCoach>[];
    for (final role in const <String>['COACH', 'HEAD_COACH']) {
      final response = await _api.get('/admin/staff',
          query: <String, dynamic>{'role': role, 'limit': 100});
      for (final e in response.dataList) {
        final j = asMap(e);
        result.add(ClassCoach(str(j, 'id'), str(j, 'fullName')));
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }
}
