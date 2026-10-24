import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/branch_admin/data/branch_admin_api.dart';
import 'package:hvp_forging/features/branch_admin/data/branch_admin_repository_impl.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_admin_repository.dart';

import '../../helpers/scripted_adapter.dart';

const AppConfig _config =
    AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

void main() {
  test('getBranches asks for inactive branches and maps the new fields',
      () async {
    final dio = createApiDio(
      config: _config,
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'a', refreshToken: 'r')),
    );
    final adapter = ScriptedAdapter((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'b1',
            'code': 'Q1',
            'name': 'The Corner',
            'address': '12 Nguyễn Huệ',
            'openingHours': '06:00 – 21:30',
            'isActive': true,
            'qrVersion': '1',
          },
          <String, dynamic>{
            'id': 'b2',
            'code': 'Q2',
            'name': 'Old',
            'address': null,
            'isActive': false
          },
        ]));
    dio.httpClientAdapter = adapter;
    final repo = BranchAdminRepositoryImpl(BranchAdminApi(ApiClient(dio)));

    final list = await repo.getBranches();

    final req = adapter.requests.single;
    expect(req.path, '/branches');
    expect(req.queryParameters['includeInactive'], true);
    expect(list.first.addressLine, '12 Nguyễn Huệ · 06:00 – 21:30');
    expect(list.first.qrVersion, '1');
    expect(list.last.isActive, isFalse);
    expect(list.last.addressLine, '');
    expect(visibleBranches(list, showInactive: false).map((b) => b.id),
        <String>['b1']);
    expect(visibleBranches(list, showInactive: true), hasLength(2));
  });
}
