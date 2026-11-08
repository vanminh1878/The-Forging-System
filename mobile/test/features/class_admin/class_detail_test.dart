import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/class_admin/domain/class_models.dart';
import 'package:hvp_forging/features/class_admin/presentation/screens/class_detail_screen.dart';
import 'package:hvp_forging/features/reception_checkin/domain/member_hit.dart';
import 'package:hvp_forging/features/reception_checkin/presentation/reception_providers.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'support.dart';

class _FakeSearch implements MemberSearchRepository {
  @override
  Future<MemberSearchResult> search(String query) async =>
      const MemberSearchResult(items: <MemberHit>[
        MemberHit(
            id: 'm2',
            memberCode: 'HVP-000200',
            fullName: 'Trần Thị B',
            status: 'ACTIVE',
            phone: '0901'),
      ], total: 1);
}

void main() {
  test('repository: detail roster, enrol body and remove path', () async {
    final t = buildRepo((o) => o.method == 'GET'
        ? okEnvelope(<String, dynamic>{
            ...classJson,
            'roster': <dynamic>[
              <String, dynamic>{
                'enrollmentId': 'e1',
                'memberId': 'm1',
                'memberCode': 'HVP-1',
                'fullName': 'A'
              }
            ]
          })
        : okEnvelope(<String, dynamic>{'ended': true}));
    final d = await t.repo.detail('c1');
    expect(d.roster.single.memberId, 'm1');
    await t.repo.enrol('c1', 'm2');
    await t.repo.removeMember('c1', 'm1');
    expect(t.adapter.requests[1].path, '/admin/classes/c1/enrollments');
    expect(t.adapter.requests[1].data, <String, dynamic>{'memberId': 'm2'});
    expect(t.adapter.requests[2].method, 'DELETE');
    expect(t.adapter.requests[2].path, '/admin/classes/c1/enrollments/m1');
  });

  Future<FakeClassRepository> show(WidgetTester tester,
      [FakeClassRepository? repo]) async {
    final fake = repo ?? FakeClassRepository();
    await pumpHvp(tester, const ClassDetailScreen(classId: 'c1'), overrides: [
      ...classOverrides(fake),
      memberSearchRepositoryProvider.overrideWithValue(_FakeSearch()),
    ]);
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('shows the roster; empty roster message', (tester) async {
    await show(tester);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    await show(tester, FakeClassRepository()..roster = []);
    expect(find.text('Lớp chưa có học viên.'), findsOneWidget);
  });

  testWidgets('enrol: search, Thêm, toast', (tester) async {
    final repo = await show(tester);
    await tester.tap(find.widgetWithText(HvpButton, '+ THÊM HỌC VIÊN VÀO LỚP'));
    await tester.pumpAndSettle();
    expect(find.text('Trần Thị B'), findsOneWidget); // listed before typing
    await tester.enterText(find.byType(TextField).last, 'Trần');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'THÊM'));
    await tester.pumpAndSettle();
    expect(repo.enrolled, <String>['m2']);
    expect(find.text('Đã thêm vào lớp.'), findsOneWidget);
  });

  testWidgets('enrol error (class full) is shown and the sheet stays',
      (tester) async {
    final repo = FakeClassRepository()
      ..enrolError = const ApiException(
          code: 'CLASS_FULL', message: 'Lớp đã đủ sĩ số', statusCode: 409);
    await show(tester, repo);
    await tester.tap(find.widgetWithText(HvpButton, '+ THÊM HỌC VIÊN VÀO LỚP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Trần');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'THÊM'));
    await tester.pumpAndSettle();
    expect(find.text('Lớp đã đủ sĩ số'), findsOneWidget);
  });

  testWidgets('remove asks for confirmation then calls the API',
      (tester) async {
    final repo = await show(tester);
    await tester.tap(find.byTooltip('Cho rời lớp'));
    await tester.pumpAndSettle();
    expect(repo.removed, isEmpty);
    await tester.tap(find.widgetWithText(HvpButton, 'CHO RỜI LỚP'));
    await tester.pumpAndSettle();
    expect(repo.removed, <String>['m1']);
  });

  testWidgets('load error shows the API message', (tester) async {
    final repo = _Failing();
    await show(tester, repo);
    expect(find.textContaining('Lớp học not found'), findsOneWidget);
  });
}

class _Failing extends FakeClassRepository {
  @override
  Future<ClassDetail> detail(String id) async => throw const ApiException(
      code: 'NOT_FOUND', message: 'Lớp học not found', statusCode: 404);
}
