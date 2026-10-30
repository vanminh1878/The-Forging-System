import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/staff/domain/staff_models.dart';
import 'package:hvp_forging/features/staff/domain/staff_repository.dart';
import 'package:hvp_forging/features/staff/presentation/screens/staff_directory_screen.dart';
import 'package:hvp_forging/features/staff/presentation/staff_providers.dart';

import '../../helpers/test_harness.dart';

const member = StaffMember(
    id: 'coach',
    fullName: 'Mai Nguyễn',
    roles: <String>['COACH'],
    accountStatus: 'ACTIVE',
    phone: '0901234567',
    email: 'mai@example.com',
    branchId: 'q7',
    branchName: 'HVP Quận 7',
    mustChangePassword: true);

class FakeStaffRepository implements StaffRepository {
  final queries = <StaffQuery>[];
  Future<StaffPage> Function(StaffQuery)? handler;
  @override
  Future<StaffPage> search(StaffQuery query) async {
    queries.add(query);
    return handler == null
        ? StaffPage(
            items: const <StaffMember>[member],
            page: query.page,
            total: 21,
            totalPages: 2)
        : handler!(query);
  }

  @override
  Future<List<StaffBranch>> branches() async =>
      const <StaffBranch>[StaffBranch('q7', 'HVP Quận 7')];

  @override
  Future<StaffMember> update(String staffId, UpdateStaffInput input) async =>
      member;

  @override
  Future<StaffMember> setStatus(String staffId,
          {required StaffStatus status, required String reason}) async =>
      member;
}

Future<void> showDirectory(
    WidgetTester tester, FakeStaffRepository repo) async {
  await pumpHvp(tester, const Scaffold(body: StaffDirectoryScreen()),
      overrides: [
        currentUserIdProvider.overrideWithValue('admin'),
        staffRepositoryProvider.overrideWithValue(repo),
      ]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'shows compact staff rows and opens real profile values in a popup',
      (tester) async {
    final repo = FakeStaffRepository();
    await showDirectory(tester, repo);
    expect(find.text('Mai Nguyễn'), findsOneWidget);
    expect(find.text('21 nhân sự · Trang 1/2'), findsOneWidget);
    await tester.tap(find.text('Mai Nguyễn'));
    await tester.pumpAndSettle();
    expect(find.text('HỒ SƠ NHÂN SỰ'), findsOneWidget);
    expect(find.text('mai@example.com'), findsOneWidget);
    expect(find.text('Cần đổi ở lần đăng nhập đầu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('debounces rapid search and resets pagination', (tester) async {
    final repo = FakeStaffRepository();
    await showDirectory(tester, repo);
    await tester.enterText(find.byType(TextFormField), 'M');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextFormField), 'Mai');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.queries.length, 1);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(repo.queries.last.q, 'Mai');
    expect(repo.queries.last.page, 1);
    expect(repo.queries.length, 2);
  });

  testWidgets(
      'combines role, account status and branch filters, then clears them',
      (tester) async {
    final repo = FakeStaffRepository();
    await showDirectory(tester, repo);
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tất cả vai trò').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lễ tân').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tất cả trạng thái').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vô hiệu hóa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tất cả chi nhánh').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('HVP Quận 7').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ÁP DỤNG BỘ LỌC'));
    await tester.tap(find.text('ÁP DỤNG BỘ LỌC'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.role, StaffRole.receptionist);
    expect(repo.queries.last.status, StaffStatus.disabled);
    expect(repo.queries.last.branchId, 'q7');
    expect(find.text('Bộ lọc (3)'), findsOneWidget);
    await tester.tap(find.text('Xóa tìm kiếm / lọc'));
    await tester.pumpAndSettle();
    expect(repo.queries.last, const StaffQuery());
  });

  testWidgets(
      'requests the next server page, and refresh does not lose filters',
      (tester) async {
    final repo = FakeStaffRepository();
    await showDirectory(tester, repo);
    await tester.ensureVisible(find.text('Trang sau'));
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.page, 2);
    expect(find.text('21 nhân sự · Trang 2/2'), findsOneWidget);
    await tester.tap(find.byTooltip('Làm mới danh sách'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.page, 2);
  });

  testWidgets('shows a retryable API failure and recovers', (tester) async {
    final repo = FakeStaffRepository()
      ..handler = (_) => Future<StaffPage>.error(const ApiException(
          code: 'FORBIDDEN', message: 'Không có quyền', statusCode: 403));
    await showDirectory(tester, repo);
    expect(find.text('Không có quyền'), findsOneWidget);
    repo.handler = null;
    await tester.tap(find.text('THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(find.text('Mai Nguyễn'), findsOneWidget);
  });

  testWidgets('ignores a late response from an older search', (tester) async {
    final old = Completer<StaffPage>();
    final repo = FakeStaffRepository()
      ..handler = (query) async {
        if (query.q == 'old') return old.future;
        return StaffPage(
            items: query.q == 'new'
                ? const <StaffMember>[]
                : const <StaffMember>[member],
            page: 1,
            total: 0,
            totalPages: 1);
      };
    await showDirectory(tester, repo);
    await tester.enterText(find.byType(TextFormField), 'old');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField), 'new');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    old.complete(const StaffPage(
        items: <StaffMember>[member], page: 1, total: 1, totalPages: 1));
    await tester.pumpAndSettle();
    expect(find.text('Mai Nguyễn'), findsNothing);
    expect(find.text('KHÔNG CÓ NHÂN SỰ PHÙ HỢP'), findsOneWidget);
  });
}
