import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/features/class_admin/domain/class_models.dart';
import 'package:hvp_forging/features/class_admin/presentation/screens/class_list_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'support.dart';

void main() {
  group('repository', () {
    test('list sends the type filter and paging and reads meta', () async {
      final t = buildRepo((o) => okEnvelope(<dynamic>[
            classJson
          ], meta: <String, dynamic>{
            'page': 2,
            'limit': 20,
            'total': 21,
            'totalPages': 2
          }));
      final page =
          await t.repo.list(const ClassQuery(sessionTypeCode: 'PT', page: 2));
      expect(t.adapter.requests.single.path, '/admin/classes');
      expect(t.adapter.requests.single.queryParameters,
          <String, dynamic>{'page': 2, 'limit': 20, 'sessionTypeCode': 'PT'});
      expect(page.totalPages, 2);
      expect(page.items.single.weekdays, <int>[1, 3, 5]);
      expect(page.items.single.capacity, 20);
      expect(page.items.single.enrolledCount, 12);
    });

    test('null capacity means no limit; no filter sends no sessionTypeCode',
        () async {
      final t = buildRepo((o) => okEnvelope(<dynamic>[
            <String, dynamic>{...classJson, 'capacity': null}
          ]));
      final page = await t.repo.list(const ClassQuery());
      expect(page.items.single.capacity, isNull);
      expect(
          t.adapter.requests.single.queryParameters
              .containsKey('sessionTypeCode'),
          isFalse);
    });

    test('parses packageTypeId / packageName (null when not in a package)',
        () async {
      final t = buildRepo((o) => okEnvelope(<dynamic>[
            <String, dynamic>{
              ...classJson,
              'packageTypeId': 'p1',
              'packageName': 'BOOK I'
            },
            classJson,
          ]));
      final items = (await t.repo.list(const ClassQuery())).items;
      expect(items[0].packageTypeId, 'p1');
      expect(items[0].packageName, 'BOOK I');
      expect(items[1].packageTypeId, isNull);
    });

    test('coaches merges COACH and HEAD_COACH sorted by name', () async {
      final t = buildRepo((o) => okEnvelope(o.queryParameters['role'] == 'COACH'
          ? <dynamic>[
              <String, dynamic>{'id': 'k2', 'fullName': 'Zed'}
            ]
          : <dynamic>[
              <String, dynamic>{'id': 'k1', 'fullName': 'Anh'}
            ]));
      final coaches = await t.repo.coaches();
      expect(coaches.map((c) => c.name), <String>['Anh', 'Zed']);
    });
  });

  group('screen', () {
    Future<FakeClassRepository> show(WidgetTester tester,
        [FakeClassRepository? repo]) async {
      final fake = repo ?? FakeClassRepository();
      await pumpHvp(tester, const Scaffold(body: ClassListScreen()),
          overrides: classOverrides(fake));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('shows weekdays, time, branch, coach and enrolment',
        (tester) async {
      await show(tester);
      expect(find.text('Boxing sáng'), findsOneWidget);
      expect(find.textContaining('T2, T4, T6 · 06:30'), findsOneWidget);
      expect(find.textContaining('HVP Quận 7 · Coach Mai Nguyễn · 12/20'),
          findsOneWidget);
    });

    testWidgets('shows the package name when the class belongs to one',
        (tester) async {
      final repo = FakeClassRepository()
        ..onList = (q) async => ClassPage(
            items: <ClassSummary>[packagedClass, sampleClass],
            page: 1,
            total: 2,
            totalPages: 1);
      await show(tester, repo);
      expect(find.text('Gói: BOOK I'), findsOneWidget);
    });

    testWidgets('a filter pill reloads with the type code', (tester) async {
      final repo = await show(tester);
      await tester.ensureVisible(find.text('PT 1:1'));
      await tester.tap(find.text('PT 1:1'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.sessionTypeCode, 'PT');
    });

    testWidgets('empty list', (tester) async {
      final repo = FakeClassRepository()
        ..onList = (q) async => const ClassPage(
            items: <ClassSummary>[], page: 1, total: 0, totalPages: 1);
      await show(tester, repo);
      expect(find.text('Không có lớp thuộc loại này.'), findsOneWidget);
    });

    testWidgets('error shows the API message and retry', (tester) async {
      final repo = FakeClassRepository()
        ..onList = (q) async => throw const ApiException(
            statusCode: 403, code: 'FORBIDDEN', message: 'Không đủ quyền');
      await show(tester, repo);
      expect(find.textContaining('Không đủ quyền'), findsOneWidget);
    });

    testWidgets('paging moves to the next page', (tester) async {
      final repo = FakeClassRepository()
        ..onList = (q) async => ClassPage(
            items: const <ClassSummary>[sampleClass],
            page: q.page,
            total: 30,
            totalPages: 2);
      await show(tester, repo);
      await tester.tap(find.text('Trang sau'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.page, 2);
    });
  });
}
