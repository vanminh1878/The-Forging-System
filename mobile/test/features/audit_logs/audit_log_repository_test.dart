import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/audit_logs/data/audit_log_repository.dart';

import '../../helpers/scripted_adapter.dart';

void main() {
  test('lists audit records with the Admin filters and maps data', () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'admin', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter((_) => okEnvelope(<Object>[
          <String, dynamic>{
            'id': 8,
            'action': 'CHALLENGE_CREATED',
            'entityType': 'CHALLENGE',
            'entityId': 'challenge-1',
            'actorType': 'USER',
            'actorId': 'admin-1',
            'actorName': 'Khoa',
            'reason': 'Tạo Challenge tuần',
            'beforeData': null,
            'afterData': <String, dynamic>{'status': 'DRAFT'},
            'createdAt': '2026-11-18T03:30:00.000Z',
          }
        ], meta: <String, dynamic>{
          'page': 2,
          'limit': 20,
          'total': 21,
          'totalPages': 2
        }));
    dio.httpClientAdapter = adapter;

    final page = await AuditLogRepositoryImpl(ApiClient(dio)).list(
      action: ' CHALLENGE_CREATED ',
      entityType: ' CHALLENGE ',
      entityId: ' challenge-1 ',
      from: DateTime.utc(2026, 11, 1),
      to: DateTime.utc(2026, 11, 30),
      page: 2,
    );

    expect(page.total, 21);
    expect(page.items.single.actorName, 'Khoa');
    expect(page.items.single.afterData, <String, dynamic>{'status': 'DRAFT'});
    expect(adapter.requests.single.path, '/admin/audit-logs');
    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'page': 2,
      'limit': 20,
      'action': 'CHALLENGE_CREATED',
      'entityType': 'CHALLENGE',
      'entityId': 'challenge-1',
      'from': '2026-11-01T00:00:00.000Z',
      'to': '2026-11-30T00:00:00.000Z',
    });
  });
}
