import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/class_admin/data/class_dto.dart';
import 'package:hvp_forging/features/class_admin/domain/class_models.dart';
import 'package:hvp_forging/features/class_admin/presentation/screens/class_detail_screen.dart';
import 'package:hvp_forging/features/class_admin/presentation/screens/class_list_screen.dart';
import 'package:hvp_forging/features/class_admin/presentation/screens/coach_classes_screen.dart';
import 'package:hvp_forging/features/courses/domain/course.dart';
import 'package:hvp_forging/features/courses/presentation/course_providers.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'support.dart';

class _FakeCourses implements CourseRepository {
  @override
  Future<List<Course>> courses() async => const <Course>[];

  @override
  Future<CourseDetail> course(String courseId) async => const CourseDetail(
        course: Course(
            id: 'k1',
            code: 'BOOK I',
            name: 'BOOK I · Nền tảng',
            durationWeeks: 8,
            totalLessons: 2,
            progress: CourseProgress(
                status: CourseStatus.notStarted, lessonsCompleted: 0)),
        lessons: <LessonSummary>[
          LessonSummary(
              lessonNo: 1,
              weekNo: 1,
              title: 'Tư thế đứng',
              isAssessment: false,
              isGraduation: false,
              isAdvanced: false),
          LessonSummary(
              lessonNo: 2,
              weekNo: 2,
              title: 'Kiểm tra tuần 2',
              isAssessment: true,
              isGraduation: false,
              isAdvanced: false),
        ],
      );

  @override
  Future<Lesson> lesson(String courseId, int lessonNo) =>
      throw UnimplementedError();
}

const _withCourse = ClassSummary(
  id: 'c1',
  branchId: 'b1',
  name: 'Boxing sáng',
  sessionTypeCode: 'GROUP',
  courseId: 'k1',
  weekdays: <int>[1, 3, 5],
  startTime: '06:30',
  durationMinutes: 60,
  capacity: 20,
  isActive: true,
  enrolledCount: 12,
);

String _detailPath(String id) => '/reception/classes/$id';

void main() {
  test('coach class rows map the /coach/classes shape', () {
    final c = coachClassFromJson(const <String, dynamic>{
      'id': 'c9',
      'name': 'Kickboxing',
      'branch': <String, dynamic>{'id': 'b2', 'name': 'HVP Quận 7'},
      'sessionType': 'GROUP',
      'weekdays': <int>[2, 4],
      'startTime': '19:00',
      'durationMinutes': 90,
      'enrolledCount': 8,
    });
    expect(c.branchId, 'b2');
    expect(c.sessionTypeCode, 'GROUP');
    expect(c.weekdays, <int>[2, 4]);
    expect(c.isActive, isTrue);
    expect(c.capacity, isNull);
    expect(c.courseId, isNull);
  });

  test('repository: coachClasses calls GET /coach/classes', () async {
    final t = buildRepo((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'c9',
            'name': 'Kickboxing',
            'branch': <String, dynamic>{'id': 'b2', 'name': 'Q7'},
            'sessionType': 'GROUP',
            'weekdays': <int>[2],
            'startTime': '19:00',
            'durationMinutes': 90,
            'enrolledCount': 8,
          }
        ]));
    final list = await t.repo.coachClasses();
    expect(t.adapter.requests.single.method, 'GET');
    expect(t.adapter.requests.single.path, '/coach/classes');
    expect(list.single.name, 'Kickboxing');
  });

  group('reception list (read only)', () {
    testWidgets('shows the classes without any create or edit action',
        (tester) async {
      await pumpHvp(
          tester,
          const Scaffold(
              body: ClassListScreen(readOnly: true, detailPath: _detailPath)),
          overrides: classOverrides(FakeClassRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Boxing sáng'), findsOneWidget);
      expect(find.text('TẠO LỚP'), findsNothing);
      expect(find.text('TẠO BUỔI'), findsNothing);
      expect(find.byTooltip('Sửa lớp'), findsNothing);
      // the coach name needs the admin-only staff list, so it is not asked for
      expect(find.textContaining('Coach'), findsNothing);
    });

    testWidgets('the admin list keeps its create buttons', (tester) async {
      await pumpHvp(tester, const Scaffold(body: ClassListScreen()),
          overrides: classOverrides(FakeClassRepository()));
      await tester.pumpAndSettle();
      expect(find.text('TẠO LỚP'), findsOneWidget);
      expect(find.text('TẠO BUỔI'), findsOneWidget);
      expect(find.byTooltip('Sửa lớp'), findsOneWidget);
    });
  });

  group('class detail (read only)', () {
    Future<void> show(WidgetTester tester, FakeClassRepository repo) async {
      await pumpHvp(
          tester, const ClassDetailScreen(classId: 'c1', readOnly: true),
          overrides: <Override>[
            ...classOverrides(repo),
            courseRepositoryProvider.overrideWithValue(_FakeCourses()),
          ]);
      await tester.pumpAndSettle();
    }

    testWidgets('roster, sessions and lesson plan, but no action',
        (tester) async {
      final repo = FakeClassRepository()..detailSummary = _withCourse;
      await show(tester, repo);

      expect(find.text('Nguyễn Văn A', skipOffstage: false), findsOneWidget);
      expect(
          find.text('GIÁO ÁN / BÀI HỌC', skipOffstage: false), findsOneWidget);
      expect(
          find.text('BOOK I · Nền tảng', skipOffstage: false), findsOneWidget);
      expect(find.text('Tuần 1', skipOffstage: false), findsOneWidget);
      expect(find.text('Bài 1 · Tư thế đứng', skipOffstage: false),
          findsOneWidget);
      expect(find.text('Kiểm tra', skipOffstage: false), findsOneWidget);

      expect(find.byTooltip('Sửa lớp'), findsNothing);
      expect(find.byTooltip('Cho rời lớp'), findsNothing);
      expect(find.widgetWithText(HvpButton, 'TẠO BUỔI KIỂM TRA'), findsNothing);
      expect(find.widgetWithText(HvpButton, 'THÊM HỌC VIÊN VÀO LỚP'),
          findsNothing);
      expect(find.text('Huỷ buổi'), findsNothing);
      expect(find.textContaining('không tạo được buổi kiểm tra'), findsNothing);
    });

    testWidgets('a class without a course says there is no lesson plan',
        (tester) async {
      await show(tester, FakeClassRepository());
      expect(
          find.text('Lớp chưa gắn khóa học nên chưa có giáo án.',
              skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('an empty roster is explained', (tester) async {
      await show(tester, FakeClassRepository()..roster = <RosterEntry>[]);
      expect(find.text('Lớp chưa có học viên.', skipOffstage: false),
          findsOneWidget);
    });
  });

  group('coach classes', () {
    Future<void> show(WidgetTester tester, FakeClassRepository repo) async {
      await pumpHvp(tester, const Scaffold(body: CoachClassesScreen()),
          overrides: classOverrides(repo));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the classes assigned to the coach', (tester) async {
      final repo = FakeClassRepository();
      await show(tester, repo);
      expect(repo.coachListCalls, 1);
      expect(find.text('Boxing sáng'), findsOneWidget);
      expect(find.textContaining('T2, T4, T6 · 06:30'), findsOneWidget);
    });

    testWidgets('no assigned class shows an empty state', (tester) async {
      await show(
          tester, FakeClassRepository()..coachList = const <ClassSummary>[]);
      expect(find.text('CHƯA CÓ LỚP ĐƯỢC PHÂN CÔNG'), findsOneWidget);
    });

    testWidgets('an API error is shown with retry', (tester) async {
      final repo = FakeClassRepository()
        ..coachListError = const ApiException(
            statusCode: 403, code: 'FORBIDDEN', message: 'Không đủ quyền');
      await show(tester, repo);
      expect(find.textContaining('Không đủ quyền'), findsOneWidget);
    });
  });
}
