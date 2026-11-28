import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/admin_settings_page.dart';
import 'package:hvp_forging/features/settings/domain/admin_setting.dart';
import 'package:hvp_forging/features/settings/presentation/admin_settings_providers.dart';

import '../../helpers/test_harness.dart';

class _FakeSettingsRepository implements AdminSettingsRepository {
  @override
  Future<List<AdminSetting>> list() async => const <AdminSetting>[
        AdminSetting(
            key: 'points.sample_key',
            group: 'POINTS',
            type: 'INT',
            value: 100,
            defaultValue: 100,
            description: 'Giới hạn điểm mẫu',
            isDefault: true),
        AdminSetting(
            key: 'streak.sample_key',
            group: 'STREAK',
            type: 'INT',
            value: 3,
            defaultValue: 3,
            description: 'Mốc chuỗi mẫu',
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
    await pumpHvp(tester, const AdminSettingsPage(), overrides: [
      adminSettingsRepositoryProvider
          .overrideWithValue(_FakeSettingsRepository()),
    ]);

    // The page title is in the shell app bar, not repeated in the body.
    expect(find.text('CẤU HÌNH HỆ THỐNG'), findsNothing);
    expect(find.text('Chi nhánh'), findsOneWidget);
    expect(find.text('ĐIỂM & HẠNG'), findsOneWidget);

    await tester.tap(find.text('ĐIỂM & HẠNG'));
    await tester.pumpAndSettle();

    // Only the settings of the selected group are listed.
    expect(find.text('points.sample_key'), findsOneWidget);
    expect(find.text('Giới hạn điểm mẫu'), findsOneWidget);
    expect(find.text('streak.sample_key'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
