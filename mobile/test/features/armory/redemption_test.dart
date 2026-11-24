import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/armory/data/redemption_repository.dart';
import 'package:hvp_forging/features/armory/domain/redemption.dart';
import 'package:hvp_forging/features/armory/presentation/redemption_history_screen.dart';
import 'package:hvp_forging/features/armory/presentation/redemption_providers.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

class FakeRedemptions implements RedemptionRepository {
  final queries = <({String? status, int page})>[];

  @override
  Future<ArmoryRedemption> detail(String redemptionId) =>
      throw UnimplementedError();

  @override
  Future<void> cancel(String redemptionId, {String? reason}) async {}

  @override
  Future<RedemptionPage> history({String? status, int page = 1}) async {
    queries.add((status: status, page: page));
    return RedemptionPage(
      page: page,
      totalPages: 1,
      total: 1,
      items: <ArmoryRedemption>[
        ArmoryRedemption(
          id: 'redemption-1',
          code: 'ARM-1001',
          rewardName: 'Găng tập HVP',
          marksCost: 300,
          status: status ?? 'PENDING_PICKUP',
          requestedAt: DateTime.utc(2026, 11, 2, 8),
          pickupBranchName: 'HVP Quận 1',
        ),
      ],
    );
  }
}

void main() {
  test('ARM-09 repository maps history and sends status pagination', () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'member-token', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter((_) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'redemption-1',
            'redemptionCode': 'ARM-1001',
            'rewardName': 'Găng tập HVP',
            'marksCost': 300,
            'status': 'DELIVERED',
            'requestedAt': '2026-11-02T08:00:00.000Z',
            'pickupBranchName': 'HVP Quận 1',
          }
        ], meta: <String, dynamic>{
          'page': 2,
          'limit': 20,
          'total': 21,
          'totalPages': 2
        }));
    dio.httpClientAdapter = adapter;

    final result = await RedemptionRepositoryImpl(ApiClient(dio))
        .history(status: 'DELIVERED', page: 2);

    expect(adapter.requests.single.path, '/me/armory/redemptions');
    expect(adapter.requests.single.queryParameters,
        <String, dynamic>{'status': 'DELIVERED', 'page': 2, 'limit': 20});
    expect(result.items.single.code, 'ARM-1001');
    expect(result.totalPages, 2);
  });

  test('ARM-05 repository cancels a member redemption with an optional reason',
      () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'member-token', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter((_) => okEnvelope(<String, dynamic>{}));
    dio.httpClientAdapter = adapter;

    await RedemptionRepositoryImpl(ApiClient(dio))
        .cancel('redemption-1', reason: '  Không thể đến nhận  ');

    expect(adapter.requests.single.path,
        '/me/armory/redemptions/redemption-1/cancel');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data,
        <String, dynamic>{'reason': 'Không thể đến nhận'});
  });

  testWidgets('ARM-09 filters redemption history by status', (tester) async {
    final repo = FakeRedemptions();
    await pumpHvp(
      tester,
      const Scaffold(body: RedemptionHistoryScreen()),
      overrides: [
        currentUserIdProvider.overrideWithValue('member'),
        redemptionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Găng tập HVP'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Đã giao'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã giao'));
    await tester.pumpAndSettle();
    expect(repo.queries.last, (status: 'DELIVERED', page: 1));
    expect(tester.takeException(), isNull);
  });
}
