import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/presentation/providers/membership_providers.dart';
import 'package:hvp_forging/features/membership/presentation/screens/membership_screen.dart';

import '../../helpers/fake_membership_repository.dart';
import '../../helpers/test_harness.dart';

const _packages = <PackageType>[
  PackageType(
    id: 'p1',
    name: 'BOOK II',
    isTrial: false,
    durationDays: 84,
    totalSessions: 36,
    priceVnd: 9800000,
  ),
  PackageType(id: 'p2', name: 'Trải nghiệm', isTrial: true),
];

MyMembership _m({
  RenewNotice notice = RenewNotice.ended,
  bool early = false,
  PendingRenewal? pending,
}) =>
    MyMembership(
      memberStatus: MemberStatus.active,
      renewNotice: notice,
      canRenewEarly: early,
      pendingRenewal: pending,
    );

Future<FakeMembershipRepository> _open(
  WidgetTester tester, {
  MyMembership? membership,
  Future<List<PackageType>> Function()? packages,
  Future<void> Function(String, String?)? request,
}) async {
  final repo = FakeMembershipRepository(
    () async => membership ?? _m(),
    packages: packages ?? () async => _packages,
    request: request ?? (_, __) async {},
  );
  await pumpHvp(
    tester,
    const MembershipScreen(),
    overrides: <Override>[
      membershipRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('ĐĂNG KÝ GÓI MỚI'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every package with price and no suggestion chip',
      (tester) async {
    await _open(tester);
    await _openSheet(tester);
    expect(find.text('CHỌN GÓI TẬP'), findsOneWidget);
    expect(find.text('BOOK II'), findsOneWidget);
    expect(find.text('84 ngày · 36 buổi'), findsOneWidget);
    expect(find.text('9.800.000đ'), findsOneWidget);
    expect(find.text('Trải nghiệm'), findsOneWidget);
    expect(find.text('GÓI TRẢI NGHIỆM'), findsOneWidget);
    expect(find.text('Chưa có giá'), findsOneWidget);
    expect(find.textContaining('Gợi ý'), findsNothing);
  });

  testWidgets('send needs a choice, confirms, toasts and refreshes',
      (tester) async {
    final repo = await _open(tester);
    await _openSheet(tester);
    HvpButton send() => tester.widget<HvpButton>(
        find.widgetWithText(HvpButton, 'GỬI YÊU CẦU GIA HẠN'));
    expect(send().onPressed, isNull);

    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  tuần sau  ');
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU GIA HẠN'));
    await tester.pumpAndSettle();
    expect(find.text('GỬI YÊU CẦU GIA HẠN?'), findsOneWidget);
    expect(repo.requests, isEmpty);

    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU'));
    await tester.pumpAndSettle();

    expect(repo.requests.single.packageTypeId, 'p1');
    expect(repo.requests.single.note, '  tuần sau  ');
    expect(find.text('Đã gửi yêu cầu gia hạn tới lễ tân.'), findsOneWidget);
    expect(find.text('CHỌN GÓI TẬP'), findsNothing);
    expect(repo.membershipCalls, 2);
    // The history has its own tab: it is read fresh when the learner opens it.
    await tester.tap(find.text('LỊCH SỬ'));
    await tester.pumpAndSettle();
    expect(repo.historyCalls, 1);
  });

  testWidgets('declining the confirmation sends nothing', (tester) async {
    final repo = await _open(tester);
    await _openSheet(tester);
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU GIA HẠN'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ'));
    await tester.pumpAndSettle();
    expect(repo.requests, isEmpty);
    expect(find.text('CHỌN GÓI TẬP'), findsOneWidget);
  });

  testWidgets('duplicate request shows the API message and reloads',
      (tester) async {
    const msg =
        'Bạn đã có một yêu cầu gia hạn đang chờ xử lý. Lễ tân sẽ xử lý sớm.';
    final repo = await _open(
      tester,
      request: (_, __) async => throw const ApiException(
          code: 'RENEWAL_PENDING_EXISTS', message: msg, statusCode: 409),
    );
    await _openSheet(tester);
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU GIA HẠN'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU'));
    await tester.pumpAndSettle();
    expect(find.text(msg), findsOneWidget);
    expect(find.text('CHỌN GÓI TẬP'), findsOneWidget);
    expect(repo.membershipCalls, 2);
  });

  testWidgets('empty package list', (tester) async {
    await _open(tester, packages: () async => <PackageType>[]);
    await _openSheet(tester);
    expect(find.text('HIỆN CHƯA CÓ GÓI NÀO ĐANG BÁN'), findsOneWidget);
  });

  testWidgets('package list error offers a retry', (tester) async {
    var fail = true;
    final repo = await _open(tester, packages: () async {
      if (fail) throw const ApiException(code: 'X', message: 'Lỗi mạng');
      return _packages;
    });
    await _openSheet(tester);
    expect(find.text('Lỗi mạng'), findsOneWidget);
    fail = false;
    await tester.tap(find.widgetWithText(HvpButton, 'THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(repo.packageCalls, 2);
    expect(find.text('BOOK II'), findsOneWidget);
  });

  group('button enabled rule', () {
    HvpButton renew(WidgetTester tester, String label) =>
        tester.widget<HvpButton>(find.widgetWithText(HvpButton, label));

    testWidgets('ended notice with a pending request is disabled',
        (tester) async {
      await _open(
        tester,
        membership: _m(
            pending: PendingRenewal(
                packageName: 'BOOK II', createdAt: DateTime.utc(2026, 10, 24))),
      );
      expect(renew(tester, 'ĐĂNG KÝ GÓI MỚI').onPressed, isNull);
    });

    testWidgets('OK without early renewal is disabled', (tester) async {
      await _open(tester, membership: _m(notice: RenewNotice.ok));
      expect(renew(tester, 'ĐĂNG KÝ THÊM GÓI').onPressed, isNull);
    });

    testWidgets('OK with early renewal is enabled', (tester) async {
      await _open(tester, membership: _m(notice: RenewNotice.ok, early: true));
      expect(renew(tester, 'ĐĂNG KÝ THÊM GÓI').onPressed, isNotNull);
    });
  });
}
