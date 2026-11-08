import 'package:flutter/material.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/member_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/reception_memberships/domain/member_rules.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'desk_harness.dart';
import 'renewal_requests_test.dart' show pageMeta, renewalJson;

Map<String, dynamic> hitJson(String id, String name,
        {String? pkg, String? end, String status = 'ACTIVE'}) =>
    <String, dynamic>{
      'userId': id,
      'memberCode': 'HVP-$id',
      'fullName': name,
      'phone': '0912345678',
      'status': status,
      'packageName': pkg,
      'packageEndDate': end,
    };

Map<String, dynamic> profileJson({String status = 'ACTIVE', String? reason}) =>
    <String, dynamic>{
      'userId': 'm1',
      'memberCode': 'HVP-m1',
      'fullName': 'Nguyễn Thị Lan',
      'phone': '0912345678',
      'email': 'lan@example.com',
      'status': status,
      'statusReason': reason,
      'joinedAt': '2026-01-05T03:00:00.000Z',
      'homeBranchName': 'HVP The Corner',
    };

Map<String, dynamic> pkgJson(String id, String name, {bool active = true}) =>
    <String, dynamic>{
      'id': id,
      'packageType': <String, dynamic>{
        'id': 'pt',
        'name': name,
        'isTrial': false
      },
      'status': active ? 'ACTIVE' : 'SCHEDULED',
      'startDate': '2026-09-01',
      'endDate': '2026-11-30',
      'totalSessions': 36,
      'usedSessions': 30,
      if (active) ...<String, dynamic>{
        'sessionsRemaining': 6,
        'daysRemaining': 20,
        'endingSoon': true
      },
    };

Map<String, dynamic> membershipJson(
        {bool current = true, bool scheduled = false}) =>
    <String, dynamic>{
      'memberStatus': 'ACTIVE',
      'current': current ? pkgJson('ms1', 'BOOK I') : null,
      'scheduled': scheduled ? pkgJson('ms2', 'BOOK II', active: false) : null,
      'pendingRenewal': null,
      'renewNotice': 'OK',
      'canRenewEarly': false,
    };

Map<String, Reply> detailRoutes(
        {Map<String, dynamic>? profile, Map<String, dynamic>? membership}) =>
    <String, Reply>{
      'GET /renewal-requests': (_) =>
          okEnvelope(<dynamic>[renewalJson('r1', 'X')], meta: pageMeta(1, 1)),
      'GET /members/m1': (_) => okEnvelope(profile ?? profileJson()),
      'GET /members/m1/membership': (_) =>
          okEnvelope(membership ?? membershipJson()),
    };

Future<void> openMembersTab(WidgetTester tester) async {
  await tester.tap(find.text('Học viên').first);
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  test('reception cancels only waiting packages, admin also running ones', () {
    expect(canCancelPackage(isAdmin: false, scheduled: true), isTrue);
    expect(canCancelPackage(isAdmin: false, scheduled: false), isFalse);
    expect(canCancelPackage(isAdmin: true, scheduled: false), isTrue);
  });

  testWidgets(
      'MEM-15 search shows package, expiry and status; empty and error are handled',
      (tester) async {
    var mode = 'ok';
    final desk = Desk(<String, Reply>{
      ...detailRoutes(),
      'GET /members': (o) {
        if (mode == 'error') {
          return errorEnvelope(500, 'INTERNAL', 'Máy chủ lỗi');
        }
        if (mode == 'empty') {
          return okEnvelope(<dynamic>[], meta: pageMeta(1, 0));
        }
        return okEnvelope(<dynamic>[
          hitJson('m1', 'Nguyễn Thị Lan', pkg: 'BOOK I', end: '2026-11-30'),
          hitJson('m2', 'Lan Anh', status: 'FROZEN')
        ], meta: pageMeta(1, 2));
      },
    });
    await pumpDeskApp(tester, desk);
    await openMembersTab(tester);
    expect(desk.calls('GET /members').single.queryParameters.containsKey('q'),
        isFalse);
    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);

    await search(tester, 'lan');
    expect(desk.calls('GET /members').last.queryParameters,
        containsPair('q', 'lan'));
    expect(find.text('BOOK I · hết hạn 30/11/2026'), findsOneWidget);
    expect(find.text('HOẠT ĐỘNG'), findsOneWidget);
    expect(find.text('ĐÓNG BĂNG'), findsOneWidget);
    expect(find.text('CHƯA CÓ GÓI'), findsOneWidget);

    mode = 'empty';
    await search(tester, 'zzz');
    expect(find.text('KHÔNG TÌM THẤY HỌC VIÊN'), findsOneWidget);

    mode = 'error';
    await search(tester, 'boom');
    expect(find.text('Máy chủ lỗi'), findsOneWidget);
  });

  testWidgets(
      'MEM-15 opens the detail with account, status reason and packages',
      (tester) async {
    final desk = Desk(<String, Reply>{
      ...detailRoutes(
          profile: profileJson(status: 'FROZEN', reason: 'Đi công tác'),
          membership: membershipJson(scheduled: true)),
      'GET /members': (_) => okEnvelope(<dynamic>[
            hitJson('m1', 'Nguyễn Thị Lan', pkg: 'BOOK I', end: '2026-11-30')
          ], meta: pageMeta(1, 1)),
    });
    await pumpDeskApp(tester, desk);
    await openMembersTab(tester);
    await search(tester, 'lan');
    await tester.tap(find.text('Nguyễn Thị Lan'));
    await tester.pumpAndSettle();

    expect(find.text('lan@example.com'), findsOneWidget);
    expect(find.text('ĐÓNG BĂNG'), findsOneWidget);
    expect(find.text('Lý do: Đi công tác'), findsOneWidget);
    expect(find.text('BOOK I'), findsOneWidget);
    expect(find.text('BOOK II'), findsOneWidget);
    expect(find.text('01/09/2026 → 30/11/2026 · còn 20 ngày'), findsOneWidget);
    expect(find.text('01/09/2026 → 30/11/2026'), findsOneWidget);
    expect(find.text('30/36 buổi đã dùng · còn 6'), findsNWidgets(2));

    final before = desk.calls('GET /members').length;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(desk.calls('GET /members').length, before + 1);
  });

  testWidgets('MEM-15 detail shows the API error (404) with retry',
      (tester) async {
    final desk = Desk(<String, Reply>{
      'GET /members/m1': (_) =>
          errorEnvelope(404, 'NOT_FOUND', 'Không tìm thấy học viên'),
      'GET /members/m1/membership': (_) =>
          errorEnvelope(404, 'NOT_FOUND', 'Không tìm thấy học viên'),
    });
    await pumpHvp(tester, const MemberDetailScreen(memberId: 'm1'),
        overrides: desk.overrides);
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy học viên'), findsOneWidget);
    expect(find.text('THỬ LẠI'), findsOneWidget);
  });

  testWidgets(
      'MEM-14 reception cancels a waiting package with a reason, not the running one',
      (tester) async {
    final desk = Desk(<String, Reply>{
      ...detailRoutes(membership: membershipJson(scheduled: true)),
      'POST /memberships/ms2/cancel': (_) =>
          okEnvelope(<String, dynamic>{'membership': <String, dynamic>{}}),
    });
    await pumpHvp(tester, const MemberDetailScreen(memberId: 'm1'),
        overrides: desk.overrides);
    await tester.pumpAndSettle();

    expect(find.text('HUỶ GÓI ĐANG HOẠT ĐỘNG'), findsNothing);
    await tester.tap(find.text('HUỶ GÓI NỐI TIẾP'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ GÓI'));
    await tester.pump();
    expect(find.text('Vui lòng nhập lý do huỷ.'), findsWidgets);
    expect(desk.calls('POST /memberships/ms2/cancel'), isEmpty);

    await tester.enterText(find.byType(TextField).last, 'Học viên đổi ý');
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ GÓI'));
    await tester.pumpAndSettle();
    expect(desk.calls('POST /memberships/ms2/cancel').single.data,
        <String, dynamic>{'reason': 'Học viên đổi ý'});
    expect(find.text('Đã huỷ gói tập.'), findsOneWidget);
    expect(desk.calls('GET /members/m1'), hasLength(2));
  });

  testWidgets(
      'MEM-14 admin also sees the cancel button on the running package; the API refusal is shown',
      (tester) async {
    final admin = Desk(
      <String, Reply>{
        ...detailRoutes(),
        'POST /memberships/ms1/cancel': (_) => errorEnvelope(
            409, 'CANCEL_SCHEDULED_FIRST', 'Huỷ gói nối tiếp trước.'),
      },
      user: const AuthUser(
          id: 'ad',
          fullName: 'Admin',
          appRole: AppRole.admin,
          roles: <String>['ADMIN']),
    );
    await pumpHvp(tester, const MemberDetailScreen(memberId: 'm1'),
        overrides: admin.overrides);
    await tester.pumpAndSettle();

    await tester.tap(find.text('HUỶ GÓI ĐANG HOẠT ĐỘNG'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Sai gói');
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ GÓI'));
    await tester.pumpAndSettle();
    expect(find.text('Huỷ gói nối tiếp trước.'), findsOneWidget);
  });
}
