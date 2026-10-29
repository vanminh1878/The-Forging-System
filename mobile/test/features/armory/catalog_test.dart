import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/armory/data/catalog_repository.dart';
import 'package:hvp_forging/features/armory/domain/catalog.dart';
import 'package:hvp_forging/features/armory/presentation/armory_catalog_screen.dart';
import 'package:hvp_forging/features/armory/presentation/catalog_providers.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

class FakeCatalog implements ArmoryCatalogRepository {
  final queries = <({String? tier, int page})>[];
  @override
  Future<List<ArmoryTier>> tiers() async =>
      const <ArmoryTier>[ArmoryTier(code: 'GEAR', name: 'Gear', minMarks: 50)];
  @override
  Future<RewardPage> rewards({String? tierCode, int page = 1}) async {
    queries.add((tier: tierCode, page: page));
    return RewardPage(
        page: page,
        totalPages: 2,
        total: 21,
        items: <ArmoryReward>[
          ArmoryReward(
              id: '1',
              name: tierCode == null ? 'Bình nước' : 'Găng tay',
              marksCost: 120,
              stock: tierCode == null ? 2 : 0,
              minRankName: 'THE INITIATED',
              perMemberLimit: 1,
              limitPeriod: 'MONTH'),
        ]);
  }
}

void main() {
  test('ARM-01 repository sends tier and pagination and maps inventory',
      () async {
    final dio = createApiDio(
        config: const AppConfig(
            apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
        tokens: MemoryTokenStore(const StoredTokens(
            accessToken: 'member-token', refreshToken: 'refresh')));
    final adapter = ScriptedAdapter((request) {
      if (request.path == '/armory/tiers') {
        return okEnvelope(<dynamic>[
          <String, dynamic>{'code': 'GEAR', 'name': 'Gear', 'minMarks': 50}
        ]);
      }
      return okEnvelope(<dynamic>[
        <String, dynamic>{
          'id': '1',
          'name': 'Gift',
          'marksCost': 100,
          'stock': 0,
          'minRankName': 'Rank II'
        }
      ], meta: <String, dynamic>{
        'page': 2,
        'limit': 20,
        'total': 21,
        'totalPages': 2
      });
    });
    dio.httpClientAdapter = adapter;
    final repo = ArmoryCatalogRepositoryImpl(ApiClient(dio));
    expect((await repo.tiers()).single.name, 'Gear');
    final result = await repo.rewards(tierCode: 'GEAR', page: 2);
    expect(adapter.requests.last.path, '/armory/rewards');
    expect(adapter.requests.last.queryParameters,
        <String, dynamic>{'tierCode': 'GEAR', 'page': 2, 'limit': 20});
    expect(result.items.single.stock, 0);
    expect(result.items.single.minRankName, 'Rank II');
    expect(result.totalPages, 2);
  });

  testWidgets('selects a tier, shows unavailable stock and resets page',
      (tester) async {
    final repo = FakeCatalog();
    await pumpHvp(tester, const Scaffold(body: ArmoryCatalogScreen()),
        overrides: [
          currentUserIdProvider.overrideWithValue('member'),
          armoryCatalogRepositoryProvider.overrideWithValue(repo),
        ]);
    await tester.pumpAndSettle();
    expect(find.text('Bình nước'), findsOneWidget);
    await tester.tap(find.text('Gear'));
    await tester.pumpAndSettle();
    expect(repo.queries.last, (tier: 'GEAR', page: 1));
    expect(find.text('Găng tay'), findsOneWidget);
    expect(find.text('HẾT HÀNG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the selected reward and its supplied conditions',
      (tester) async {
    final repo = FakeCatalog();
    await pumpHvp(tester, const Scaffold(body: ArmoryCatalogScreen()),
        overrides: [
          currentUserIdProvider.overrideWithValue('member'),
          armoryCatalogRepositoryProvider.overrideWithValue(repo),
        ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bình nước'));
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT PHẦN QUÀ'), findsOneWidget);
    expect(find.text('ĐIỀU KIỆN ĐỔI'), findsOneWidget);
    expect(find.text('THE INITIATED'), findsOneWidget);
    expect(find.text('1 / tháng'), findsOneWidget);
    expect(find.text('Chưa có mô tả.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
