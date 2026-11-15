import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/hvp_theme.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/admin_settings_page.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/admin_renewal_requests_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'desk_harness.dart';
import 'renewal_requests_test.dart' show pageMeta, renewalJson;

const _admin = AuthUser(
    id: 'ad',
    fullName: 'Admin',
    appRole: AppRole.admin,
    roles: <String>['ADMIN']);

Map<String, Reply> _routes() {
  var done = false;
  return <String, Reply>{
    'GET /renewal-requests': (_) => okEnvelope(
        done ? <dynamic>[] : <dynamic>[renewalJson('r1', 'Nguyễn Văn A')],
        meta: pageMeta(1, done ? 0 : 1)),
    'GET /package-types/p1/classes': (_) => okEnvelope(<dynamic>[]),
    'POST /renewal-requests/r1/approve': (_) {
      done = true;
      return okEnvelope(<String, dynamic>{'message': 'Đã duyệt gói BOOK II.'});
    },
  };
}

void main() {
  testWidgets(
      'AMB-07 Cấu hình > Khác opens the inbox; admin approves with the photo',
      (tester) async {
    final desk = Desk(_routes(), user: _admin);
    HvpFonts.useGoogleFonts = false;
    hvpEntranceEnabled = false;
    usePhoneSurface(tester);
    final router = GoRouter(routes: <RouteBase>[
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: AdminSettingsPage())),
      GoRoute(
          path: AdminPaths.renewalRequests,
          builder: (_, __) => const AdminRenewalRequestsScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: desk.overrides,
      child: MaterialApp.router(
          theme: HvpTheme.light(),
          darkTheme: HvpTheme.dark(),
          themeMode: ThemeMode.dark,
          routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Khác'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khác'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yêu cầu gia hạn'));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('ĐỒNG Ý · ĐÃ THU PHÍ'), findsNothing);
    await tester.tap(find.text('ĐÃ THU PHÍ · DUYỆT'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<HvpButton>(
                find.widgetWithText(HvpButton, 'XÁC NHẬN & KÍCH HOẠT GÓI'))
            .onPressed,
        isNull);
    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    await tester
        .tap(find.widgetWithText(HvpButton, 'XÁC NHẬN & KÍCH HOẠT GÓI'));
    await tester.pumpAndSettle();

    expect(desk.calls('POST /renewal-requests/r1/approve').single.data,
        <String, dynamic>{'paymentEvidenceUrl': kEvidenceUrl});
    expect(find.text('Đã duyệt gói BOOK II.'), findsOneWidget);
    expect(find.text('Không có yêu cầu gia hạn nào đang chờ.'), findsOneWidget);
  });

  testWidgets('AMB-07 admin can cancel a request with a reason too',
      (tester) async {
    final desk = Desk(<String, Reply>{
      ..._routes(),
      'POST /renewal-requests/r1/cancel': (_) => okEnvelope(renewalJson(
          'r1', 'Nguyễn Văn A',
          status: 'CANCELLED', reason: 'Sai gói')),
    }, user: _admin);
    await pumpHvp(tester, const AdminRenewalRequestsScreen(),
        overrides: desk.overrides);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ YÊU CẦU'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Sai gói');
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ YÊU CẦU').last);
    await tester.pumpAndSettle();
    expect(desk.calls('POST /renewal-requests/r1/cancel').single.data,
        <String, dynamic>{'reason': 'Sai gói'});
  });
}
