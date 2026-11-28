import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/admin_settings_page.dart';
import 'package:hvp_forging/features/settings/domain/admin_setting.dart';
import 'package:hvp_forging/features/settings/presentation/admin_settings_providers.dart';

import '../../helpers/test_harness.dart';

class _FakeSettingsRepository implements AdminSettingsRepository {
  @override
  Future<List<AdminSetting>> list() async => const <AdminSetting>[
        AdminSetting(
            key: 'points.dp_monthly_cap',
            group: 'POINTS',
            type: 'INT',
            value: 1200,
            defaultValue: 1200,
            description: '',
            isDefault: true),
      ];

  @override
  Future<void> update(String key, Object value, String reason) async {}
  @override
  Future<void> rollback(String key, int auditId, String reason) async {}
}

void main() {
  testWidgets('CFG-04 renders configuration tabs and changes the active group',
      (tester) async {
    await pumpHvp(tester, const AdminSettingsPage(), overrides: <Override>[
      adminSettingsRepositoryProvider
          .overrideWithValue(_FakeSettingsRepository()),
    ]);

    // The page title is in the shell app bar, not repeated in the body.
    expect(find.text('CẤU HÌNH HỆ THỐNG'), findsNothing);
    expect(find.text('Chi nhánh'), findsOneWidget);
    expect(find.text('ĐIỂM & HẠNG'), findsOneWidget);

    await tester.tap(find.text('ĐIỂM & HẠNG'));
    await tester.pumpAndSettle();

    expect(find.text('Hạn mức DP mỗi tháng'), findsOneWidget);

    final armoryTab = find.text('ARMORY');
    await tester.ensureVisible(armoryTab);
    await tester.tap(armoryTab);
    await tester.pumpAndSettle();

    expect(find.text('Quản lý Armory'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
