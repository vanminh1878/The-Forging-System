import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/hvp_theme.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';
import 'package:hvp_forging/features/audit_logs/domain/audit_log.dart';
import 'package:hvp_forging/features/audit_logs/presentation/audit_log_providers.dart';
import 'package:hvp_forging/features/audit_logs/presentation/audit_logs_screen.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/admin_settings_page.dart';

import '../../helpers/test_harness.dart';

class _FakeAuditLogs implements AuditLogRepository {
  _FakeAuditLogs({this.empty = false});
  final bool empty;
  String? lastAction;

  @override
  Future<AuditLogPage> list(
      {String? action,
      String? entityType,
      String? entityId,
      DateTime? from,
      DateTime? to,
      int page = 1}) async {
    lastAction = action;
    return AuditLogPage(
      items: empty
          ? const <AuditLogEntry>[]
          : <AuditLogEntry>[
              AuditLogEntry(
                id: 1,
                action: 'CHALLENGE_CREATED',
                entityType: 'CHALLENGE',
                entityId: 'challenge-1',
                actorType: 'USER',
                actorName: 'Khoa',
                reason: 'Tạo thử thách',
                createdAt: DateTime.utc(2026, 11, 18, 3, 30),
              ),
            ],
      page: page,
      totalPages: 1,
      total: empty ? 0 : 1,
    );
  }
}

void main() {
  testWidgets('shows audit records and applies an action filter',
      (tester) async {
    final repo = _FakeAuditLogs();
    await pumpHvp(tester, const AuditLogsScreen(), overrides: <Override>[
      auditLogRepositoryProvider.overrideWithValue(repo)
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Thay đổi hệ thống'), findsOneWidget);
    expect(find.textContaining('Khoa'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'EMPTY');
    await tester.tap(find.text('ÁP DỤNG'));
    await tester.pump();
    expect(repo.lastAction, 'EMPTY');
  });

  testWidgets('shows the empty Audit Log state', (tester) async {
    await pumpHvp(tester, const AuditLogsScreen(), overrides: <Override>[
      auditLogRepositoryProvider.overrideWithValue(_FakeAuditLogs(empty: true))
    ]);
    await tester.pumpAndSettle();

    expect(find.text('CHƯA CÓ NHẬT KÝ'), findsOneWidget);
  });

  testWidgets('Cấu hình > Khác opens the Audit Log screen', (tester) async {
    HvpFonts.useGoogleFonts = false;
    hvpEntranceEnabled = false;
    usePhoneSurface(tester);
    final router = GoRouter(routes: <RouteBase>[
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: AdminSettingsPage())),
      GoRoute(
          path: AdminPaths.auditLogs,
          builder: (_, __) => const AuditLogsScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        auditLogRepositoryProvider.overrideWithValue(_FakeAuditLogs())
      ],
      child: MaterialApp.router(
          theme: HvpTheme.light(),
          darkTheme: HvpTheme.dark(),
          themeMode: ThemeMode.dark,
          routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Khác'));
    await tester.tap(find.text('Khác'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhật ký Audit'));
    await tester.pumpAndSettle();

    expect(find.text('Nhật ký Audit'), findsOneWidget);
    expect(find.text('Thay đổi hệ thống'), findsOneWidget);
  });
}
