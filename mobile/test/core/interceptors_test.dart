import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/network/token_refresher.dart';
import 'package:hvp_forging/core/storage/token_store.dart';

import '../helpers/scripted_adapter.dart';

class _FakeRefresher implements TokenRefresher {
  _FakeRefresher({this.fail = false});

  final bool fail;
  int calls = 0;

  @override
  Future<StoredTokens> refresh(String refreshToken) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (fail) {
      throw const ApiException(code: 'REFRESH_INVALID', message: 'Hết hạn', statusCode: 401);
    }
    return const StoredTokens(accessToken: 'new-access', refreshToken: 'new-refresh');
  }
}

const AppConfig _config = AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

ResponseBody _serve(RequestOptions o) {
  if (o.headers['Authorization'] == 'Bearer new-access') return okEnvelope(<String, dynamic>{'ok': true});
  return errorEnvelope(401, 'UNAUTHORIZED', 'Hết phiên');
}

void main() {
  test('sends the bearer token and the tenant header', () async {
    final tokens = MemoryTokenStore(const StoredTokens(accessToken: 'new-access', refreshToken: 'r'));
    final dio = createApiDio(config: _config, tokens: tokens, refresher: _FakeRefresher());
    final adapter = ScriptedAdapter(_serve);
    dio.httpClientAdapter = adapter;

    final res = await ApiClient(dio).get('/data');

    expect(res.dataMap['ok'], true);
    expect(adapter.requests.single.headers['X-Tenant-Code'], 'hvp');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer new-access');
  });

  test('parallel 401s trigger exactly one refresh and all requests succeed', () async {
    final tokens = MemoryTokenStore(const StoredTokens(accessToken: 'old-access', refreshToken: 'old-refresh'));
    final refresher = _FakeRefresher();
    final dio = createApiDio(config: _config, tokens: tokens, refresher: refresher);
    dio.httpClientAdapter = ScriptedAdapter(_serve);
    final api = ApiClient(dio);

    final results = await Future.wait(<Future<ApiEnvelope>>[
      api.get('/data'),
      api.get('/data'),
      api.get('/data'),
    ]);

    expect(results.length, 3);
    expect(refresher.calls, 1);
    final stored = await tokens.read();
    expect(stored!.accessToken, 'new-access');
    expect(stored.refreshToken, 'new-refresh');
  });

  test('a rejected refresh clears the session and surfaces the 401', () async {
    final tokens = MemoryTokenStore(const StoredTokens(accessToken: 'old-access', refreshToken: 'old-refresh'));
    var expired = 0;
    final dio = createApiDio(
      config: _config,
      tokens: tokens,
      refresher: _FakeRefresher(fail: true),
      onSessionExpired: () => expired++,
    );
    dio.httpClientAdapter = ScriptedAdapter(_serve);

    await expectLater(
      ApiClient(dio).get('/data'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );

    expect(expired, 1);
    expect(await tokens.read(), isNull);
  });

  test('requests marked auth:false never carry a token or refresh', () async {
    final tokens = MemoryTokenStore(const StoredTokens(accessToken: 'old-access', refreshToken: 'old-refresh'));
    final refresher = _FakeRefresher();
    final dio = createApiDio(config: _config, tokens: tokens, refresher: refresher);
    final adapter = ScriptedAdapter((o) => errorEnvelope(401, 'INVALID_CREDENTIALS', 'Sai mật khẩu'));
    dio.httpClientAdapter = adapter;

    await expectLater(
      ApiClient(dio).post('/auth/login', auth: false, body: <String, dynamic>{'identifier': 'a', 'password': 'b'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
    );

    expect(refresher.calls, 0);
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('a plain 422 is not retried and keeps the backend code', () async {
    final tokens = MemoryTokenStore(const StoredTokens(accessToken: 'new-access', refreshToken: 'r'));
    final dio = createApiDio(config: _config, tokens: tokens, refresher: _FakeRefresher());
    final adapter = ScriptedAdapter((o) => errorEnvelope(422, 'TRIAL_NOT_AVAILABLE', 'Chưa đủ điều kiện'));
    dio.httpClientAdapter = adapter;

    await expectLater(
      ApiClient(dio).post('/me/rank-trials'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TRIAL_NOT_AVAILABLE')),
    );
    expect(adapter.requests.length, 1);
  });
}
