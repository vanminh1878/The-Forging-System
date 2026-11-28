import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/audit_logs/domain/audit_log.dart';
import 'package:hvp_forging/features/audit_logs/presentation/audit_log_providers.dart';
import 'package:hvp_forging/features/settings/domain/admin_setting.dart';
import 'package:hvp_forging/features/settings/presentation/admin_settings_providers.dart';
import 'package:hvp_forging/features/settings/presentation/config_history_screen.dart';

import '../../helpers/test_harness.dart';

class _AuditRepo implements AuditLogRepository {
  @override
  Future<AuditLogPage> list(
          {String? query,
          String? action,
          String? entityType,
          String? entityId,
          DateTime? from,
          DateTime? to,
          int page = 1}) async =>
      AuditLogPage(items: <AuditLogEntry>[
        AuditLogEntry(
            id: 9,
            action: 'CONFIG_CHANGE',
            entityType: 'SYSTEM_CONFIG',
            entityId: 'points.dp_monthly_cap',
            actorType: 'USER',
            actorName: 'Admin',
            reason: 'Điều chỉnh',
            createdAt: DateTime.utc(2026))
      ], page: page, totalPages: 1, total: 1);
}

class _SettingsRepo implements AdminSettingsRepository {
  int rollbacks = 0;
  @override
  Future<List<AdminSetting>> list() async => const <AdminSetting>[];
  @override
  Future<void> rollback(String key, int auditId, String reason) async =>
      rollbacks++;
  @override
  Future<void> update(String key, Object value, String reason) async {}
}

void main() {
  testWidgets('shows config audit history', (tester) async {
    final settings = _SettingsRepo();
    await pumpHvp(tester, const ConfigHistoryScreen(), overrides: <Override>[
      auditLogRepositoryProvider.overrideWithValue(_AuditRepo()),
      adminSettingsRepositoryProvider.overrideWithValue(settings)
    ]);
    await tester.pumpAndSettle();
    expect(find.text('points.dp_monthly_cap'), findsOneWidget);
    expect(find.text('HOÀN TÁC'), findsOneWidget);
  });
}
