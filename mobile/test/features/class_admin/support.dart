import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hvp_forging/core/branch/branch.dart';
import 'package:hvp_forging/core/branch/branch_providers.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/class_admin/data/class_repository_impl.dart';
import 'package:hvp_forging/features/class_admin/domain/class_models.dart';
import 'package:hvp_forging/features/class_admin/domain/class_repository.dart';
import 'package:hvp_forging/features/class_admin/presentation/class_providers.dart';
import 'package:hvp_forging/features/courses/domain/course.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/package_admin/presentation/providers/package_admin_providers.dart';
import 'package:hvp_forging/features/courses/presentation/course_providers.dart';

import '../../helpers/scripted_adapter.dart';

({ClassRepositoryImpl repo, ScriptedAdapter adapter}) buildRepo(
    ResponseBody Function(RequestOptions) handler) {
  final dio = createApiDio(
    config: const AppConfig(
        apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
    tokens: MemoryTokenStore(const StoredTokens(
        accessToken: 'admin-token', refreshToken: 'refresh')),
  );
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (repo: ClassRepositoryImpl(ApiClient(dio)), adapter: adapter);
}

const classJson = <String, dynamic>{
  'id': 'c1',
  'branchId': 'b1',
  'name': 'Boxing sáng',
  'sessionTypeCode': 'GROUP',
  'courseId': null,
  'defaultCoachId': 'k1',
  'weekdays': <int>[1, 3, 5],
  'startTime': '06:30',
  'durationMinutes': 60,
  'capacity': 20,
  'isActive': true,
  'enrolledCount': 12,
};

const sampleClass = ClassSummary(
  id: 'c1',
  branchId: 'b1',
  name: 'Boxing sáng',
  sessionTypeCode: 'GROUP',
  defaultCoachId: 'k1',
  weekdays: <int>[1, 3, 5],
  startTime: '06:30',
  durationMinutes: 60,
  capacity: 20,
  isActive: true,
  enrolledCount: 12,
);

/// Overrides every provider the class screens read, so no test touches the network.
List<Override> classOverrides(ClassRepository repo) => <Override>[
      currentUserIdProvider.overrideWithValue('admin'),
      classRepositoryProvider.overrideWithValue(repo),
      coursesProvider.overrideWith((ref) async => const <Course>[]),
      adminPackagesProvider.overrideWith((ref) async => const <PackageType>[
            PackageType(id: 'p1', name: 'BOOK I'),
            PackageType(id: 'p2', name: 'BOOK II', isActive: false),
          ]),
      branchesProvider.overrideWith((ref) async =>
          const <Branch>[Branch(id: 'b1', code: 'Q7', name: 'HVP Quận 7')]),
    ];

/// [sampleClass] sold in the package `p1`.
final packagedClass = ClassSummary(
  id: sampleClass.id,
  branchId: sampleClass.branchId,
  name: sampleClass.name,
  sessionTypeCode: sampleClass.sessionTypeCode,
  defaultCoachId: sampleClass.defaultCoachId,
  weekdays: sampleClass.weekdays,
  startTime: sampleClass.startTime,
  durationMinutes: sampleClass.durationMinutes,
  capacity: sampleClass.capacity,
  isActive: true,
  enrolledCount: sampleClass.enrolledCount,
  packageTypeId: 'p1',
  packageName: 'BOOK I',
);

class FakeClassRepository implements ClassRepository {
  final queries = <ClassQuery>[];
  Future<ClassPage> Function(ClassQuery)? onList;

  @override
  Future<ClassPage> list(ClassQuery query) async {
    queries.add(query);
    return onList != null
        ? onList!(query)
        : ClassPage(
            items: const <ClassSummary>[sampleClass],
            page: query.page,
            total: 1,
            totalPages: 1);
  }

  final created = <ClassDraft>[];
  final updated = <Map<String, Object?>>[];
  Object? createError;

  @override
  Future<ClassSummary> create(ClassDraft draft) async {
    if (createError != null) throw createError!;
    created.add(draft);
    return sampleClass;
  }

  @override
  Future<ClassSummary> update(String id, Map<String, Object?> changes) async {
    updated.add(changes);
    return sampleClass;
  }

  final enrolled = <String>[];
  final removed = <String>[];
  Object? enrolError;
  var roster = <RosterEntry>[
    const RosterEntry(
        enrollmentId: 'e1',
        memberId: 'm1',
        memberCode: 'HVP-000123',
        fullName: 'Nguyễn Văn A'),
  ];

  @override
  Future<ClassDetail> detail(String id) async =>
      ClassDetail(summary: sampleClass, roster: roster);

  @override
  Future<void> enrol(String classId, String memberId) async {
    if (enrolError != null) throw enrolError!;
    enrolled.add(memberId);
  }

  @override
  Future<void> removeMember(String classId, String memberId) async =>
      removed.add(memberId);

  final cancelled = <String>[];
  Object? cancelError;
  var sessionList = <ClassSession>[
    ClassSession(
        id: 's1',
        title: 'Boxing sáng',
        startsAt: DateTime.now().add(const Duration(days: 2)),
        status: 'SCHEDULED',
        isExam: false,
        attendeeCount: 0,
        coachName: 'Mai Nguyễn'),
    ClassSession(
        id: 's0',
        title: 'Boxing sáng',
        startsAt: DateTime.now().subtract(const Duration(days: 1)),
        status: 'SCHEDULED',
        isExam: false,
        attendeeCount: 3),
    ClassSession(
        id: 's2',
        title: 'Boxing sáng',
        startsAt: DateTime.now().add(const Duration(days: 4)),
        status: 'CANCELLED',
        isExam: false,
        attendeeCount: 0),
  ];

  @override
  Future<List<ClassSession>> sessions(String classId) async => sessionList;

  @override
  Future<void> cancelSession(String sessionId, String reason) async {
    if (cancelError != null) throw cancelError!;
    cancelled.add('$sessionId|$reason');
  }

  final sessionsCreated = <SessionDraft>[];
  final exams = <String>[];

  @override
  Future<void> createSession(SessionDraft draft) async =>
      sessionsCreated.add(draft);

  @override
  Future<void> createExamSession(String classId, String date,
          {String? title}) async =>
      exams.add('$classId|$date|$title');

  @override
  Future<List<ClassCoach>> coaches() async =>
      const <ClassCoach>[ClassCoach('k1', 'Mai Nguyễn')];
}
