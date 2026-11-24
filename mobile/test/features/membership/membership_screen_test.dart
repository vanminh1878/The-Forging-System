import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/app/shell/profile_tab.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/empty_state.dart';
import 'package:hvp_forging/core/widgets/error_state.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/core/widgets/shimmer_box.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/presentation/providers/membership_providers.dart';
import 'package:hvp_forging/features/membership/presentation/screens/membership_screen.dart';

import '../../helpers/fake_membership_repository.dart';
import '../../helpers/test_harness.dart';

const _current = MemberPackage(
  id: 'c',
  name: 'BOOK I — Foundation',
  isTrial: false,
  startDate: '2026-09-01',
  endDate: '2026-11-01',
  totalSessions: 36,
  usedSessions: 30,
  sessionsRemaining: 6,
  daysRemaining: 7,
  endingSoon: true,
);

const _queued = MemberPackage(
  id: 's',
  name: 'BOOK II',
  isTrial: false,
  startDate: '2026-11-02',
  endDate: '2027-02-01',
  totalSessions: 36,
);

Future<FakeMembershipRepository> _pump(
    WidgetTester tester, Future<MyMembership> Function() result) async {
  final repo = FakeMembershipRepository(result);
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

MyMembership _m({
  MemberStatus status = MemberStatus.active,
  MemberPackage? current,
  MemberPackage? scheduled,
  PendingRenewal? pending,
  RenewNotice notice = RenewNotice.ok,
}) =>
    MyMembership(
      memberStatus: status,
      current: current,
      scheduled: scheduled,
      pendingRenewal: pending,
      renewNotice: notice,
    );

void main() {
  testWidgets('shows shimmer while loading', (tester) async {
    final completer = Completer<MyMembership>();
    await pumpHvp(
      tester,
      const MembershipScreen(),
      overrides: <Override>[
        membershipRepositoryProvider.overrideWithValue(
            FakeMembershipRepository(() => completer.future)),
        currentUserIdProvider.overrideWithValue('u1'),
      ],
    );
    await tester.pump();
    expect(find.byType(ShimmerList), findsWidgets);
    completer.complete(_m(notice: RenewNotice.noPackage));
    await tester.pumpAndSettle();
  });

  testWidgets('error state retries', (tester) async {
    var fail = true;
    final repo = await _pump(tester, () async {
      if (fail) throw const ApiException(code: 'X', message: 'Lỗi mạng');
      return _m(notice: RenewNotice.noPackage);
    });
    expect(find.byType(ErrorState), findsOneWidget);
    fail = false;
    await tester.tap(find.byType(HvpButton));
    await tester.pumpAndSettle();
    expect(repo.membershipCalls, 2);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('NO_PACKAGE', (tester) async {
    await _pump(tester, () async => _m(notice: RenewNotice.noPackage));
    expect(find.text('CHƯA CÓ GÓI TẬP'), findsOneWidget);
    expect(find.text('Bạn chưa có gói tập, liên hệ lễ tân để đăng ký.'),
        findsOneWidget);
  });

  testWidgets('ENDED', (tester) async {
    await _pump(tester, () async => _m(notice: RenewNotice.ended));
    expect(find.text('GÓI TẬP ĐÃ KẾT THÚC'), findsOneWidget);
    expect(
        find.textContaining('DP, Marks và hạng của bạn vẫn được giữ nguyên.'),
        findsOneWidget);
  });

  testWidgets('active package with queued package and pending request',
      (tester) async {
    await _pump(
      tester,
      () async => _m(
        current: _current,
        scheduled: _queued,
        pending: PendingRenewal(
            packageName: 'BOOK III', createdAt: DateTime.utc(2026, 10, 24, 5)),
      ),
    );
    expect(find.text('BOOK I — Foundation'), findsOneWidget);
    expect(find.text('SẮP HẾT HẠN'), findsOneWidget);
    expect(find.text('còn 7 ngày'), findsOneWidget);
    expect(find.text('30/36 buổi đã dùng · còn 6'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('01/11/2026'), findsOneWidget);
    expect(find.text('02/11/2026 → 01/02/2027'), findsOneWidget);
    expect(
        find.text(
            'Gói này tự kích hoạt khi gói hiện tại hết hạn, thời hạn không bị mất.'),
        findsOneWidget);
    expect(find.text('Đã gửi yêu cầu · chờ lễ tân xác nhận'), findsOneWidget);
    expect(find.text('CHỜ DUYỆT'), findsOneWidget);
    expect(find.text('BOOK III · gửi 24/10/2026'), findsOneWidget);
  });

  testWidgets('unlimited sessions and no expiry', (tester) async {
    await _pump(
      tester,
      () async => _m(
        current: const MemberPackage(
          id: 'c',
          name: 'Gói thử',
          isTrial: true,
          startDate: '2026-10-01',
          usedSessions: 3,
        ),
      ),
    );
    expect(find.text('3 buổi đã tập · Không giới hạn'), findsOneWidget);
    expect(find.text('Không thời hạn'), findsOneWidget);
    expect(find.text('GÓI THỬ'), findsOneWidget);
    expect(find.text('ĐANG HOẠT ĐỘNG'),
        findsNWidgets(2)); // account + package chips
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('FROZEN account on last day', (tester) async {
    await _pump(
      tester,
      () async => _m(
        status: MemberStatus.frozen,
        current: MemberPackage(
          id: 'c',
          name: _current.name,
          isTrial: false,
          startDate: _current.startDate,
          endDate: _current.endDate,
          totalSessions: 36,
          usedSessions: 10,
          daysRemaining: 0,
        ),
      ),
    );
    expect(find.text('ĐÓNG BĂNG'), findsOneWidget);
    expect(find.text('Hôm nay là ngày cuối'), findsOneWidget);
  });

  testWidgets('banner variants on the package screen', (tester) async {
    await _pump(tester,
        () async => _m(status: MemberStatus.frozen, notice: RenewNotice.ended));
    expect(
        find.text('Tài khoản đang đóng băng — chế độ chỉ xem'), findsOneWidget);
    expect(find.text('ĐĂNG KÝ / GIA HẠN GÓI ĐỂ MỞ LẠI'), findsOneWidget);
  });

  testWidgets('ended banner', (tester) async {
    await _pump(tester, () async => _m(notice: RenewNotice.ended));
    expect(find.text('Gói tập đã kết thúc.'), findsOneWidget);
    expect(find.text('ĐĂNG KÝ GÓI MỚI'), findsOneWidget);
  });

  testWidgets('expiring banner follows the server values', (tester) async {
    await _pump(tester,
        () async => _m(current: _current, notice: RenewNotice.endingSoon));
    expect(find.text('Gói sắp kết thúc — còn 7 ngày'), findsOneWidget);
    expect(find.text('GIA HẠN NGAY'), findsOneWidget);
    expect(find.text('+50 MARKS'), findsOneWidget);
  });

  testWidgets('no-plan banner is not repeated here', (tester) async {
    await _pump(tester, () async => _m(notice: RenewNotice.noPackage));
    expect(find.text('Chào mừng! Bạn chưa có gói tập'), findsNothing);
  });

  testWidgets('renewal history lists status, package, date and reason',
      (tester) async {
    final repo = FakeMembershipRepository(
      () async => _m(notice: RenewNotice.noPackage),
      history: () async => <RenewalRequest>[
        RenewalRequest(
          id: 'r1',
          status: RenewalStatus.cancelled,
          packageName: 'BOOK II',
          priceVnd: 9800000,
          reason: 'Chưa nhận được tiền',
          createdAt: DateTime.utc(2026, 10, 24, 5),
        ),
        RenewalRequest(
          id: 'r2',
          status: RenewalStatus.completed,
          packageName: 'BOOK I',
          createdAt: DateTime.utc(2026, 8, 1, 5),
        ),
      ],
    );
    await pumpHvp(tester, const MembershipScreen(), overrides: <Override>[
      membershipRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u1'),
    ]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('BOOK I'), 200);
    expect(find.text('ĐÃ HUỶ'), findsOneWidget);
    expect(find.text('ĐÃ GIA HẠN'), findsOneWidget);
    expect(find.text('Gửi 24/10/2026 · 9.800.000đ'), findsOneWidget);
    expect(find.text('Lý do huỷ: Chưa nhận được tiền'), findsOneWidget);
    expect(find.text('Gửi 01/08/2026 · Chưa có giá'), findsOneWidget);
  });

  testWidgets('empty history', (tester) async {
    await _pump(tester, () async => _m(notice: RenewNotice.noPackage));
    await tester.scrollUntilVisible(
        find.text('Bạn chưa gửi yêu cầu gia hạn nào'), 200);
    expect(find.text('Bạn chưa gửi yêu cầu gia hạn nào'), findsOneWidget);
  });

  testWidgets('history error stays inline and retries', (tester) async {
    var fail = true;
    final repo = FakeMembershipRepository(
      () async => _m(notice: RenewNotice.noPackage),
      history: () async {
        if (fail) throw const ApiException(code: 'X', message: 'Lỗi lịch sử');
        return <RenewalRequest>[];
      },
    );
    await pumpHvp(tester, const MembershipScreen(), overrides: <Override>[
      membershipRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u1'),
    ]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lỗi lịch sử'), 200);
    expect(find.text('CHƯA CÓ GÓI TẬP'), findsOneWidget);
    fail = false;
    await tester.tap(find.widgetWithText(HvpButton, 'THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(repo.historyCalls, 2);
    expect(find.text('Bạn chưa gửi yêu cầu gia hạn nào'), findsOneWidget);
  });

  testWidgets('ProfileTab row pushes the membership route', (tester) async {
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: ProfileTab())),
        GoRoute(
            path: StudentPaths.membership,
            builder: (_, __) => const Text('MEMBERSHIP PAGE')),
      ],
    );
    addTearDown(router.dispose);
    usePhoneSurface(tester);
    await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.pump();
    await tester.tap(find.text('Gói tập & gia hạn'));
    await tester.pumpAndSettle();
    expect(find.text('MEMBERSHIP PAGE'), findsOneWidget);
  });
}
