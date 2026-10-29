import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/branch/branch.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/empty_state.dart';
import 'package:hvp_forging/core/widgets/error_state.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_admin_repository.dart';
import 'package:hvp_forging/features/branch_admin/presentation/providers/branch_admin_providers.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/branch_list_screen.dart';

import '../../helpers/test_harness.dart';

class _FakeRepo implements BranchAdminRepository {
  _FakeRepo(this.result);

  final Future<List<Branch>> Function() result;

  @override
  Future<List<Branch>> getBranches() => result();
}

Future<void> _pump(
    WidgetTester tester, Future<List<Branch>> Function() result) async {
  await pumpHvp(
    tester,
    const BranchListScreen(),
    overrides: <Override>[
      branchAdminRepositoryProvider.overrideWithValue(_FakeRepo(result)),
      currentUserIdProvider.overrideWithValue('admin-1'),
    ],
  );
  await tester.pumpAndSettle();
}

const _active = Branch(
  id: 'b1',
  code: 'Q1',
  name: 'The Corner',
  address: '12 Nguyễn Huệ',
  openingHours: '06:00 – 21:30',
  qrVersion: '3',
);
const _inactive =
    Branch(id: 'b2', code: 'Q2', name: 'Chi nhánh cũ', isActive: false);

void main() {
  testWidgets('shows active branches only, then inactive ones after the toggle',
      (tester) async {
    await _pump(tester, () async => <Branch>[_active, _inactive]);

    expect(find.text('The Corner'), findsOneWidget);
    expect(find.text('12 Nguyễn Huệ · 06:00 – 21:30'), findsOneWidget);
    expect(find.text('Mã QR: phiên bản 3'), findsOneWidget);
    expect(find.text('ĐANG HOẠT ĐỘNG'), findsOneWidget);
    expect(find.text('Chi nhánh cũ'), findsNothing);

    await tester.tap(find.text('Hiện chi nhánh ngừng hoạt động'));
    await tester.pumpAndSettle();

    expect(find.text('Chi nhánh cũ'), findsOneWidget);
    expect(find.text('NGỪNG HOẠT ĐỘNG'), findsOneWidget);
    expect(find.textContaining('Mã QR'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state', (tester) async {
    await _pump(tester, () async => <Branch>[]);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('CHƯA CÓ CHI NHÁNH NÀO.'), findsOneWidget);
  });

  testWidgets('error shows the error state and retry reloads', (tester) async {
    var calls = 0;
    await _pump(tester, () async {
      calls++;
      if (calls == 1) {
        throw const ApiException(
            code: 'SERVER_ERROR', message: 'Lỗi mạng', statusCode: 500);
      }
      return <Branch>[_active];
    });
    expect(find.byType(ErrorState), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(ErrorState), matching: find.byType(HvpButton)));
    await tester.pumpAndSettle();
    expect(find.text('The Corner'), findsOneWidget);
  });
}
