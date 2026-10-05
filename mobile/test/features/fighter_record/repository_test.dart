import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/fighter_record/data/fighter_record_api.dart';
import 'package:hvp_forging/features/fighter_record/data/fighter_record_repository_impl.dart';
import 'package:hvp_forging/features/fighter_record/domain/points_models.dart';

import '../../helpers/scripted_adapter.dart';

const AppConfig _config = AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

({FighterRecordRepositoryImpl repo, ScriptedAdapter adapter}) _build(ResponseBody Function(RequestOptions) handler) {
  final dio = createApiDio(
    config: _config,
    tokens: MemoryTokenStore(const StoredTokens(accessToken: 'a', refreshToken: 'r')),
  );
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (repo: FighterRecordRepositoryImpl(FighterRecordApi(ApiClient(dio))), adapter: adapter);
}

void main() {
  test('getTransactions sends page, limit and source as query parameters', () async {
    final t = _build((o) => okEnvelope(
          <dynamic>[],
          meta: <String, dynamic>{'page': 2, 'limit': 20, 'total': 21, 'totalPages': 2},
        ));

    final page = await t.repo.getTransactions(page: 2, limit: 20, source: PointSource.armoryRedeem);

    final request = t.adapter.requests.single;
    expect(request.path, '/me/points/transactions');
    expect(request.queryParameters['page'], 2);
    expect(request.queryParameters['limit'], 20);
    expect(request.queryParameters['source'], 'ARMORY_REDEEM');
    expect(page.hasMore, isFalse);
  });

  test('getTransactions omits source when no filter is selected', () async {
    final t = _build((o) => okEnvelope(<dynamic>[], meta: <String, dynamic>{'page': 1, 'limit': 20, 'total': 0, 'totalPages': 1}));
    await t.repo.getTransactions();
    expect(t.adapter.requests.single.queryParameters.containsKey('source'), isFalse);
  });

  test('each read hits its documented endpoint', () async {
    final t = _build((o) {
      switch (o.path) {
        case '/me/rank':
          return okEnvelope(<String, dynamic>{
            'current': <String, dynamic>{'id': 'r1', 'rankOrder': 1, 'code': 'THE_UNKNOWN', 'nameEn': 'THE UNKNOWN'},
            'next': null,
            'status': 'MAX_RANK',
          });
        case '/me/points/monthly':
          return okEnvelope(<String, dynamic>{'dpUsed': 1, 'dpCap': 2, 'marksUsed': 3, 'marksCap': 4});
        default:
          return okEnvelope(<dynamic>[]);
      }
    });

    await t.repo.getProgress();
    await t.repo.getRanks();
    await t.repo.getBadges();
    await t.repo.getHistory();
    await t.repo.getMonthlyStatus();

    expect(t.adapter.requests.map((r) => r.path), <String>[
      '/me/rank',
      '/ranks',
      '/me/badges',
      '/me/rank-history',
      '/me/points/monthly',
    ]);
  });

  test('requestRankTrial POSTs and surfaces TRIAL_NOT_AVAILABLE', () async {
    final t = _build((o) => errorEnvelope(422, 'TRIAL_NOT_AVAILABLE', 'Bạn chưa đủ điều kiện.'));

    await expectLater(
      t.repo.requestRankTrial(),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'TRIAL_NOT_AVAILABLE')
          .having((e) => e.message, 'message', 'Bạn chưa đủ điều kiện.')),
    );
    expect(t.adapter.requests.single.method, 'POST');
    expect(t.adapter.requests.single.path, '/me/rank-trials');
  });
}
