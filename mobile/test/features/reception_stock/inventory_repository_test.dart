import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/reception_stock/data/inventory_repository_impl.dart';

import '../../helpers/scripted_adapter.dart';

({InventoryRepositoryImpl repo, ScriptedAdapter adapter}) build(
  ResponseBody Function(RequestOptions) handler,
) {
  final dio = createApiDio(
    config: const AppConfig(
        apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
    tokens: MemoryTokenStore(const StoredTokens(
        accessToken: 'reception-token', refreshToken: 'refresh')),
  );
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (repo: InventoryRepositoryImpl(ApiClient(dio)), adapter: adapter);
}

void main() {
  test('GFT-07 lists filtered rewards and maps pagination', () async {
    final test = build((_) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'r1',
            'sku': 'GLOVE',
            'name': 'Găng',
            'stock': 7,
            'isActive': true
          },
        ], meta: <String, dynamic>{
          'page': 2,
          'limit': 20,
          'total': 27,
          'totalPages': 2
        }));

    final page = await test.repo.rewards(query: '  Găng ', page: 2);

    expect(test.adapter.requests.single.path, '/staff/armory/rewards');
    expect(test.adapter.requests.single.queryParameters,
        <String, dynamic>{'page': 2, 'limit': 20, 'q': 'Găng'});
    expect([page.items.single.sku, page.items.single.stock, page.hasMore],
        ['GLOVE', 7, false]);
  });

  test('GFT-08 lists stock movements and submits a trimmed adjustment',
      () async {
    final test = build((options) {
      if (options.method == 'GET') {
        return okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'm1',
            'rewardId': 'r1',
            'rewardSku': 'GLOVE',
            'rewardName': 'Găng',
            'movementType': 'IN',
            'quantity': 3,
            'createdAt': '2026-11-24T08:00:00.000Z',
          },
        ], meta: <String, dynamic>{
          'page': 1,
          'limit': 20,
          'total': 1,
          'totalPages': 1
        });
      }
      return okEnvelope(<String, dynamic>{});
    });

    final page = await test.repo.movements(rewardId: 'r1', movementType: 'IN');
    await test.repo.adjust(
        rewardId: 'r1',
        movementType: 'OUT',
        quantity: 2,
        reason: '  Hàng lỗi  ');

    expect(test.adapter.requests.first.queryParameters, <String, dynamic>{
      'page': 1,
      'limit': 20,
      'rewardId': 'r1',
      'movementType': 'IN'
    });
    expect([page.items.single.movementType, page.items.single.quantity],
        ['IN', 3]);
    expect(
        test.adapter.requests.last.path, '/staff/armory/inventory/movements');
    expect(test.adapter.requests.last.data, <String, dynamic>{
      'rewardId': 'r1',
      'movementType': 'OUT',
      'quantity': 2,
      'reason': 'Hàng lỗi'
    });
  });
}
