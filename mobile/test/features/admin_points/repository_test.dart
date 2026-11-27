import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/admin_points/data/admin_points_repository_impl.dart';

import '../../helpers/scripted_adapter.dart';

const _config =
    AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

({AdminPointsRepositoryImpl repo, ScriptedAdapter adapter}) _build(
    ResponseBody Function(RequestOptions) handler) {
  final dio = createApiDio(
      config: _config,
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'a', refreshToken: 'r')));
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (repo: AdminPointsRepositoryImpl(ApiClient(dio)), adapter: adapter);
}

void main() {
  test('uses the documented Admin points endpoints and request bodies',
      () async {
    final t = _build((request) {
      switch (request.path) {
        case '/members':
        case '/members/member-1/points/transactions':
          return okEnvelope(<dynamic>[], meta: <String, dynamic>{
            'page': 1,
            'limit': 50,
            'total': 0,
            'totalPages': 1
          });
        case '/members/member-1/points/monthly':
          return okEnvelope(<String, dynamic>{
            'dpUsed': 1,
            'dpCap': 100,
            'marksUsed': 2,
            'marksCap': 50
          });
        default:
          return okEnvelope(null, status: 201);
      }
    });

    await t.repo.searchMembers(' An ');
    await t.repo.ledger('member-1');
    await t.repo.monthlyStatus('member-1');
    await t.repo.adjust('member-1',
        dpDelta: 10, marksDelta: -2, reason: 'Sửa sổ điểm', confirmed: true);
    await t.repo.reverse('tx-1', reason: 'Nhập sai');

    expect(t.adapter.requests.map((request) => request.path), <String>[
      '/members',
      '/members/member-1/points/transactions',
      '/members/member-1/points/monthly',
      '/admin/members/member-1/points/adjust',
      '/admin/points/transactions/tx-1/reverse',
    ]);
    expect(t.adapter.requests[0].queryParameters['q'], 'An');
    expect(t.adapter.requests[1].queryParameters['limit'], 50);
    expect(t.adapter.requests[3].data, <String, dynamic>{
      'dpDelta': 10,
      'marksDelta': -2,
      'reason': 'Sửa sổ điểm',
      'confirmed': true
    });
    expect(t.adapter.requests[4].data, <String, dynamic>{'reason': 'Nhập sai'});
  });
}
