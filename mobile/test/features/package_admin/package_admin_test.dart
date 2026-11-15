import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/package_admin/domain/package_models.dart';
import 'package:hvp_forging/features/package_admin/domain/package_rules.dart';
import 'package:hvp_forging/features/package_admin/presentation/screens/package_list_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'support.dart';

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(HvpButton));
  await tester.tap(find.byType(HvpButton));
  await tester.pumpAndSettle();
}

Future<FakePackageAdminRepository> _open(
    WidgetTester tester, FakePackageAdminRepository fake) async {
  await pumpHvp(tester, const PackageListScreen(),
      overrides: packageOverrides(fake));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('rules', () {
    test('validators', () {
      expect(validatePackageCode('BOOK_1'), isNull);
      expect(validatePackageCode('book 1'), isNotNull);
      expect(validatePackageCode(''), isNotNull);
      expect(validatePackageName('  '), isNotNull);
      expect(validateOptionalInt(1, 14)(''), isNull);
      expect(validateOptionalInt(1, 14)('15'), isNotNull);
      expect(validateSortOrder('-1'), isNotNull);
      expect(classCountLabel(2), '2 lớp');
      expect(classCountLabel(0), 'Chưa có lớp');
    });

    test('draft changesFrom lists only edited fields, null clears', () {
      final before = PackageDraft.of(bookOne);
      expect(before.changesFrom(before), isEmpty);
      const after = PackageDraft(
        code: 'BOOK_1',
        name: 'BOOK I+',
        durationDays: 84,
        totalSessions: null,
        sessionsPerWeek: 3,
        isTrial: false,
        priceVnd: 8900000,
        isActive: false,
        sortOrder: 1,
      );
      expect(after.changesFrom(before), <String, Object?>{
        'name': 'BOOK I+',
        'totalSessions': null,
        'isActive': false,
      });
    });
  });

  group('repository', () {
    test('list asks for inactive packages and parses classCount', () async {
      final t = buildPackageRepo((o) => okEnvelope(<dynamic>[packageJson]));
      final list = await t.repo.list();
      expect(t.adapter.requests.single.path, '/package-types');
      expect(
          t.adapter.requests.single.queryParameters['includeInactive'], true);
      expect(list.single.classCount, 2);
      expect(list.single.code, 'BOOK_1');
      expect(list.single.isActive, isTrue);
    });

    test('create posts the draft, update patches only changes', () async {
      final t = buildPackageRepo((o) =>
          okEnvelope(packageJson, status: o.method == 'POST' ? 201 : 200));
      await t.repo.create(PackageDraft.of(bookOne));
      await t.repo.update('p1', <String, Object?>{'priceVnd': null});
      expect(t.adapter.requests[0].method, 'POST');
      expect(t.adapter.requests[0].path, '/admin/package-types');
      expect((t.adapter.requests[0].data as Map)['code'], 'BOOK_1');
      expect(t.adapter.requests[1].method, 'PATCH');
      expect(t.adapter.requests[1].path, '/admin/package-types/p1');
      expect(t.adapter.requests[1].data, <String, Object?>{'priceVnd': null});
    });

    test('409 surfaces as PACKAGE_CODE_EXISTS', () async {
      final t = buildPackageRepo((o) =>
          errorEnvelope(409, 'PACKAGE_CODE_EXISTS', 'Mã gói đã tồn tại'));
      await expectLater(
          t.repo.create(PackageDraft.of(bookOne)),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', 'PACKAGE_CODE_EXISTS')));
    });
  });

  group('list screen', () {
    testWidgets('shows price, summary, class count and the stopped tag',
        (tester) async {
      await _open(tester, FakePackageAdminRepository([bookOne, stopped]));
      expect(find.text('BOOK I'), findsOneWidget);
      expect(find.text('8.900.000đ'), findsOneWidget);
      expect(find.text('84 ngày · 36 buổi'), findsOneWidget);
      expect(find.textContaining('2 lớp'), findsOneWidget);
      expect(find.text('NGỪNG BÁN'), findsOneWidget);
      expect(find.text('Chưa có giá'), findsOneWidget);
      expect(find.text('Không giới hạn ngày · Không giới hạn buổi'),
          findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await _open(tester, FakePackageAdminRepository([]));
      expect(find.text('CHƯA CÓ GÓI TẬP NÀO'), findsOneWidget);
    });

    testWidgets('error offers retry', (tester) async {
      var fail = true;
      final fake = _ThrowingList(() => fail);
      await _open(tester, fake);
      expect(find.text('Lỗi mạng'), findsOneWidget);
      fail = false;
      await tester.tap(find.widgetWithText(HvpButton, 'THỬ LẠI'));
      await tester.pumpAndSettle();
      expect(find.text('BOOK I'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('create sends the draft, toasts and reloads', (tester) async {
      final fake = await _open(tester, FakePackageAdminRepository([]));
      await tester.tap(find.byTooltip('Thêm gói'));
      await tester.pumpAndSettle();
      await _tapSubmit(tester);
      expect(fake.created, isEmpty); // code and name are required

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'BOOK_9');
      await tester.enterText(fields.at(1), 'BOOK IX');
      await tester.enterText(fields.at(2), '90');
      await tester.enterText(fields.at(5), '9000000');
      await _tapSubmit(tester);

      final d = fake.created.single;
      expect(d.code, 'BOOK_9');
      expect(d.name, 'BOOK IX');
      expect(d.durationDays, 90);
      expect(d.totalSessions, isNull);
      expect(d.priceVnd, 9000000);
      expect(find.text('Đã tạo gói'), findsOneWidget);
      expect(fake.listCalls, 2);
    });

    testWidgets('duplicate code shows the message under the code field',
        (tester) async {
      final fake = await _open(
          tester,
          FakePackageAdminRepository(const [], onWrite: () {
            throw const ApiException(
                code: 'PACKAGE_CODE_EXISTS',
                message: 'Mã gói đã tồn tại',
                statusCode: 409);
          }));
      await tester.tap(find.byTooltip('Thêm gói'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'BOOK_1');
      await tester.enterText(fields.at(1), 'Trùng');
      await _tapSubmit(tester);
      expect(find.text('Mã gói đã tồn tại'), findsOneWidget);
      expect(find.text('Đã tạo gói'), findsNothing);
      expect(fake.created, isEmpty);
    });

    testWidgets('edit sends only the changed fields', (tester) async {
      final fake = await _open(tester, FakePackageAdminRepository([bookOne]));
      await tester.tap(find.text('BOOK I'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(5), '9500000');
      await _tapSubmit(tester);
      expect(fake.updated.single.id, 'p1');
      expect(
          fake.updated.single.changes, <String, Object?>{'priceVnd': 9500000});
      expect(find.text('Đã cập nhật gói'), findsOneWidget);
    });
  });
}

class _ThrowingList extends FakePackageAdminRepository {
  _ThrowingList(this.fail) : super([bookOne]);

  final bool Function() fail;

  @override
  Future<List<PackageType>> list() async {
    if (fail()) throw const ApiException(code: 'X', message: 'Lỗi mạng');
    return super.list();
  }
}
