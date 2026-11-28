import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/admin_points/domain/admin_points_repository.dart';
import 'package:hvp_forging/features/admin_points/presentation/admin_points_adjustment_screen.dart';
import 'package:hvp_forging/features/admin_points/presentation/admin_points_providers.dart';
import 'package:hvp_forging/features/fighter_record/domain/points_models.dart';
import 'package:hvp_forging/features/reception_checkin/domain/member_hit.dart';

import '../../helpers/test_harness.dart';

class _Repo implements AdminPointsRepository {
  int searchCount = 0;
  int adjustCount = 0;

  @override
  Future<void> adjust(String memberId,
      {required int dpDelta,
      required int marksDelta,
      required String reason,
      bool confirmed = false}) async {
    adjustCount++;
  }

  @override
  Future<PointsPage> ledger(String memberId, {int page = 1}) async =>
      const PointsPage(
          items: <PointTransaction>[], page: 1, totalPages: 1, total: 0);
  @override
  Future<MonthlyPointStatus> monthlyStatus(String memberId) async =>
      const MonthlyPointStatus(
          dpUsed: 100, dpCap: 100, marksUsed: 5, marksCap: 50);
  @override
  Future<void> reverse(String transactionId, {required String reason}) async {}
  @override
  Future<MemberSearchResult> searchMembers(String query) async {
    searchCount++;
    final adjusted = adjustCount > 0;
    return MemberSearchResult(items: <MemberHit>[
      MemberHit(
          id: 'member-1',
          memberCode: 'HVP001',
          fullName: 'An Võ',
          status: 'ACTIVE',
          dpBalance: adjusted ? 110 : 100,
          marksBalance: 50)
    ], total: 1);
  }
}

void main() {
  testWidgets(
      'finds a member and shows cap warning plus manual adjustment form',
      (tester) async {
    await pumpHvp(tester, const AdminPointsAdjustmentScreen(),
        overrides: <Override>[
          adminPointsRepositoryProvider.overrideWithValue(_Repo())
        ]);

    await tester.pump();
    await tester.pump();
    expect(find.text('An Võ'), findsOneWidget);
    await tester.tap(find.text('An Võ'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ĐÃ CHẠM HẠN MỨC THÁNG'), findsOneWidget);
    expect(find.text('ĐIỀU CHỈNH THỦ CÔNG'), findsOneWidget);
  });

  testWidgets('refreshes the selected member after an adjustment',
      (tester) async {
    final repo = _Repo();
    await pumpHvp(tester, const AdminPointsAdjustmentScreen(),
        overrides: <Override>[
          adminPointsRepositoryProvider.overrideWithValue(repo)
        ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('An Võ'));
    await tester.pumpAndSettle();

    expect(find.text('100'), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('admin-points-dp-delta')),
            matching: find.byType(TextFormField)),
        '10');
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('admin-points-reason')),
            matching: find.byType(TextFormField)),
        'Cộng điểm');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GHI NHẬN ĐIỀU CHỈNH'));
    await tester.pumpAndSettle();

    expect(repo.searchCount, greaterThan(1));
    expect(find.text('110'), findsOneWidget);
  });
}
