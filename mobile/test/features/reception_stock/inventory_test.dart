import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/reception_stock/data/inventory_repository_impl.dart';
import 'package:hvp_forging/features/reception_stock/domain/inventory.dart';
import 'package:hvp_forging/features/reception_stock/presentation/inventory_providers.dart';
import 'package:hvp_forging/features/reception_stock/presentation/reception_stock_tab.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

class FakeInventory implements InventoryRepository {
  final adjustments = <({String rewardId, String movementType, int quantity, String reason})>[];
  final movementQueries = <({String? rewardId, String? movementType, int page})>[];

  @override
  Future<InventoryRewardPage> rewards({String query = '', int page = 1}) async =>
      InventoryRewardPage(
        items: const <InventoryReward>[
          InventoryReward(
              id: 'reward-1', sku: 'GLOVES', name: 'Găng tập', stock: 10, isActive: true),
        ],
        page: page,
        totalPages: 1,
        total: 1,
      );

  @override
  Future<InventoryMovementPage> movements(
      {String? rewardId, String? movementType, int page = 1}) async {
    movementQueries.add(
        (rewardId: rewardId, movementType: movementType, page: page));
    return InventoryMovementPage(
      items: <InventoryMovement>[
        InventoryMovement(
          id: 'movement-$page',
          rewardId: 'reward-1',
          rewardSku: 'GLOVES',
          rewardName: page == 1 ? 'Găng tập' : 'Găng tập trang 2',
          movementType: 'IN',
          quantity: 5,
          createdAt: DateTime.utc(2026, 11, 2, 8),
          actorName: 'Lễ tân',
          reason: 'Nhập hàng',
        ),
      ],
      page: page,
      totalPages: 2,
      total: 2,
    );
  }

  @override
  Future<void> adjust({
    required String rewardId,
    required String movementType,
    required int quantity,
    required String reason,
  }) async {
    adjustments.add((
      rewardId: rewardId,
      movementType: movementType,
      quantity: quantity,
      reason: reason,
    ));
  }
}

void main() {
  test('GFT-02 repository maps rewards, movements and sends adjustments',
      () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'staff-token', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter((options) {
      if (options.path == '/staff/armory/rewards') {
        return okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'reward-1',
            'sku': 'GLOVES',
            'name': 'Găng tập',
            'stock': 10,
            'isActive': true,
          }
        ], meta: <String, dynamic>{
          'page': 1,
          'limit': 20,
          'total': 1,
          'totalPages': 1,
        });
      }
      if (options.path == '/staff/armory/inventory/movements' &&
          options.method == 'GET') {
        return okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'movement-1',
            'rewardId': 'reward-1',
            'rewardSku': 'GLOVES',
            'rewardName': 'Găng tập',
            'movementType': 'OUT',
            'quantity': 2,
            'redemptionId': null,
            'actorName': 'Lễ tân',
            'reason': 'Xuất kho',
            'createdAt': '2026-11-02T08:00:00.000Z',
          }
        ], meta: <String, dynamic>{
          'page': 1,
          'limit': 20,
          'total': 1,
          'totalPages': 1,
        });
      }
      return okEnvelope(<String, dynamic>{}, status: 201);
    });
    dio.httpClientAdapter = adapter;
    final repository = InventoryRepositoryImpl(ApiClient(dio));

    final rewards = await repository.rewards(query: 'găng', page: 2);
    expect(adapter.requests[0].path, '/staff/armory/rewards');
    expect(adapter.requests[0].queryParameters,
        <String, dynamic>{'page': 2, 'limit': 20, 'q': 'găng'});
    expect(rewards.items.single.stock, 10);

    final movements =
        await repository.movements(rewardId: 'reward-1', movementType: 'OUT');
    expect(adapter.requests[1].path, '/staff/armory/inventory/movements');
    expect(adapter.requests[1].queryParameters, <String, dynamic>{
      'page': 1,
      'limit': 20,
      'rewardId': 'reward-1',
      'movementType': 'OUT',
    });
    expect(movements.items.single.isInbound, isFalse);
    expect(movements.items.single.actorName, 'Lễ tân');

    await repository.adjust(
        rewardId: 'reward-1', movementType: 'IN', quantity: 5, reason: 'Nhập hàng');
    expect(adapter.requests[2].path, '/staff/armory/inventory/movements');
    expect(adapter.requests[2].method, 'POST');
    expect(adapter.requests[2].data, <String, dynamic>{
      'rewardId': 'reward-1',
      'movementType': 'IN',
      'quantity': 5,
      'reason': 'Nhập hàng',
    });
  });

  testWidgets('GFT-02 stock tab adjusts a reward and shows the history',
      (tester) async {
    final repository = FakeInventory();
    await pumpHvp(
      tester,
      const Scaffold(body: ReceptionStockTab()),
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('GLOVES · Tồn kho 10'), findsOneWidget);
    await tester.tap(find.text('NHẬP KHO'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '5');
    await tester.enterText(find.byType(TextFormField).last, 'Nhập hàng');
    await tester.tap(find.text('XÁC NHẬN NHẬP KHO'));
    await tester.pumpAndSettle();

    expect(repository.adjustments.single, (
      rewardId: 'reward-1',
      movementType: 'IN',
      quantity: 5,
      reason: 'Nhập hàng',
    ));
    await tester.tap(find.text('LỊCH SỬ'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập hàng'), findsOneWidget);
    expect(find.text('NHẬP KHO'), findsOneWidget);
    expect(find.text('Lễ tân · 02/11/2026 15:00'), findsOneWidget);
  });

  testWidgets('GFT-02 history filters and paginates movements', (tester) async {
    final repository = FakeInventory();
    await pumpHvp(
      tester,
      const Scaffold(body: ReceptionStockTab()),
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('LỊCH SỬ'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập hàng'), findsOneWidget);

    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(find.text('Găng tập trang 2'), findsOneWidget);
    expect(repository.movementQueries.last.page, 2);

    await tester.ensureVisible(find.text('Xuất kho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xuất kho'));
    await tester.pumpAndSettle();
    expect(repository.movementQueries.last.movementType, 'OUT');
    expect(repository.movementQueries.last.page, 1);
  });
}
