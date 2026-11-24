import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/armory/data/redemption_create_repository.dart';

import '../../helpers/scripted_adapter.dart';

void main() {
  test('ARM-08 creates a redemption with reward and pickup branch', () async {
    final dio = createApiDio(
      config: const AppConfig(
        apiBaseUrl: 'http://test.local/api/v1',
        tenantCode: 'hvp',
      ),
      tokens: MemoryTokenStore(const StoredTokens(
        accessToken: 'member-token',
        refreshToken: 'refresh-token',
      )),
    );
    final adapter = ScriptedAdapter(
      (_) => okEnvelope(<String, dynamic>{
        'redemption': <String, dynamic>{
          'id': '11111111-1111-4111-8111-111111111111',
          'redemptionCode': 'ARM-11111111',
          'marksCost': 120,
          'status': 'PENDING_PICKUP',
        },
        'wallet': <String, dynamic>{
          'marksBalance': 500,
          'marksHeld': 120,
          'marksAvailable': 380,
        },
        'duplicate': false,
      }),
    );
    dio.httpClientAdapter = adapter;

    final result = await RedemptionCreateRepositoryImpl(ApiClient(dio)).create(
      rewardId: '11111111-1111-4111-8111-111111111111',
      pickupBranchId: '22222222-2222-4222-8222-222222222222',
      idempotencyKey: '33333333-3333-4333-8333-333333333333',
    );

    expect(adapter.requests.single.path, '/armory/redemptions');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data, <String, dynamic>{
      'rewardId': '11111111-1111-4111-8111-111111111111',
      'pickupBranchId': '22222222-2222-4222-8222-222222222222',
      'idempotencyKey': '33333333-3333-4333-8333-333333333333',
    });
    expect(result.code, 'ARM-11111111');
    expect(result.marksCost, 120);
    expect(result.status, 'PENDING_PICKUP');
  });
}
