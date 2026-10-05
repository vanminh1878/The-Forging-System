import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/data/auth_repository_impl.dart';
import 'package:hvp_forging/features/auth/domain/auth_repository.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';

import '../../helpers/scripted_adapter.dart';

const AppConfig _config = AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

const Map<String, dynamic> _session = <String, dynamic>{
  'accessToken': 'access-1',
  'refreshToken': 'refresh-1',
  'expiresIn': 900,
  'user': <String, dynamic>{
    'id': 'u1',
    'fullName': 'Huấn Luyện Viên Mẫu',
    'email': 'coach@example.com',
    'phone': null,
    'avatarUrl': null,
    'roles': <String>['COACH'],
    'appRole': 'coach',
    'branchId': null,
  },
};

({AuthRepositoryImpl repo, MemoryTokenStore tokens, ScriptedAdapter adapter}) _build(
  ResponseBody Function(RequestOptions) handler, {
  StoredTokens? initial,
}) {
  final tokens = MemoryTokenStore(initial);
  final dio = createApiDio(config: _config, tokens: tokens);
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (repo: AuthRepositoryImpl(ApiClient(dio), tokens), tokens: tokens, adapter: adapter);
}

void main() {
  test('login stores the token pair and returns the user with its app role', () async {
    final t = _build((o) => okEnvelope(_session));

    final user = await t.repo.login(identifier: ' coach@example.com ', password: 'secret1');

    expect(user.appRole, AppRole.coach);
    final stored = await t.tokens.read();
    expect(stored!.accessToken, 'access-1');
    expect(stored.refreshToken, 'refresh-1');
    final sent = t.adapter.requests.single;
    expect(sent.path, '/auth/login');
    expect((sent.data as Map)['identifier'], 'coach@example.com');
  });

  test('wrong credentials surface the backend error and store nothing', () async {
    final t = _build((o) => errorEnvelope(401, 'INVALID_CREDENTIALS', 'Sai thông tin đăng nhập'));

    await expectLater(
      t.repo.login(identifier: 'x@y.vn', password: 'bad'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Sai thông tin đăng nhập')),
    );
    expect(await t.tokens.read(), isNull);
  });

  test('register sends passwordConfirm and omits an empty email', () async {
    final t = _build((o) => okEnvelope(_session, status: 201));

    await t.repo.register(const RegisterInput(fullName: 'An', phone: '0912345678', password: 'abc123', email: ' '));

    final body = t.adapter.requests.single.data as Map;
    expect(body['passwordConfirm'], 'abc123');
    expect(body.containsKey('email'), isFalse);
  });

  test('restoreSession returns null without stored tokens and makes no request', () async {
    final t = _build((o) => okEnvelope(null));
    expect(await t.repo.restoreSession(), isNull);
    expect(t.adapter.requests, isEmpty);
  });

  test('restoreSession loads /auth/me for a stored session', () async {
    final t = _build(
      (o) => okEnvelope((_session['user'] as Map<String, dynamic>)),
      initial: const StoredTokens(accessToken: 'a', refreshToken: 'r'),
    );
    final user = await t.repo.restoreSession();
    expect(user!.fullName, 'Huấn Luyện Viên Mẫu');
  });

  test('logout always clears local tokens, even when the request fails', () async {
    final t = _build(
      (o) => errorEnvelope(500, 'INTERNAL', 'boom'),
      initial: const StoredTokens(accessToken: 'a', refreshToken: 'r'),
    );
    await t.repo.logout();
    expect(await t.tokens.read(), isNull);
  });

  test('password reset runs through the three endpoints', () async {
    final t = _build((o) {
      switch (o.path) {
        case '/auth/password/forgot':
          return okEnvelope(<String, dynamic>{'requestId': 'req-1', 'maskedDestination': '091****678', 'devPin': '123456'});
        case '/auth/password/verify-pin':
          return okEnvelope(<String, dynamic>{'resetToken': 'token-token-token'});
        default:
          return jsonResponse(204, <String, dynamic>{});
      }
    });

    final ticket = await t.repo.requestPasswordReset('0912345678');
    expect(ticket.requestId, 'req-1');
    expect(ticket.devPin, '123456');
    final token = await t.repo.verifyResetPin(requestId: ticket.requestId, pin: '123456');
    expect(token, 'token-token-token');
    await t.repo.resetPassword(
      requestId: ticket.requestId,
      resetToken: token,
      password: 'abc123',
      passwordConfirm: 'abc123',
    );
    expect(t.adapter.requests.map((r) => r.path), <String>[
      '/auth/password/forgot',
      '/auth/password/verify-pin',
      '/auth/password/reset',
    ]);
  });
}
