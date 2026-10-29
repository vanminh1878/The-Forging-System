import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/membership/data/membership_api.dart';
import 'package:hvp_forging/features/membership/data/membership_repository_impl.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';

import '../../helpers/scripted_adapter.dart';

const AppConfig _config =
    AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

({MembershipRepositoryImpl repo, ScriptedAdapter adapter}) _build(
    ResponseBody Function(RequestOptions) handler) {
  final dio = createApiDio(
    config: _config,
    tokens: MemoryTokenStore(
        const StoredTokens(accessToken: 'a', refreshToken: 'r')),
  );
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (
    repo: MembershipRepositoryImpl(MembershipApi(ApiClient(dio))),
    adapter: adapter
  );
}

void main() {
  test('parses a full payload from /me/membership', () async {
    final t = _build((o) => okEnvelope(<String, dynamic>{
          'memberStatus': 'ACTIVE',
          'current': <String, dynamic>{
            'id': 'c1',
            'packageType': <String, dynamic>{
              'id': 't',
              'code': 'B1',
              'name': 'BOOK I',
              'isTrial': true
            },
            'startDate': '2026-09-01',
            'endDate': '2026-11-01',
            'totalSessions': 36,
            'usedSessions': 30,
            'sessionsRemaining': 6,
            'daysRemaining': 0,
            'endingSoon': true,
          },
          'scheduled': <String, dynamic>{
            'id': 's1',
            'packageType': <String, dynamic>{
              'name': 'BOOK II',
              'isTrial': false
            },
            'startDate': '2026-11-02',
            'endDate': null,
            'totalSessions': null,
          },
          'pendingRenewal': <String, dynamic>{
            'packageName': 'BOOK II',
            'createdAt': '2026-10-24T05:00:00.000Z'
          },
          'renewNotice': 'OK',
          'canRenewEarly': false,
        }));

    final m = await t.repo.getMyMembership();

    expect(t.adapter.requests.single.path, '/me/membership');
    expect(m.memberStatus, MemberStatus.active);
    expect(m.current!.name, 'BOOK I');
    expect(m.current!.isTrial, isTrue);
    expect(m.current!.daysRemaining, 0);
    expect(m.scheduled!.endDate, isNull);
    expect(m.scheduled!.totalSessions, isNull);
    expect(m.pendingRenewal!.packageName, 'BOOK II');
    expect(m.renewNotice, RenewNotice.ok);
  });

  test('null current / scheduled / pendingRenewal stay null', () async {
    final t = _build((o) => okEnvelope(<String, dynamic>{
          'memberStatus': 'FROZEN',
          'current': null,
          'scheduled': null,
          'pendingRenewal': null,
          'renewNotice': 'NO_PACKAGE',
          'canRenewEarly': false,
        }));
    final m = await t.repo.getMyMembership();
    expect(m.current, isNull);
    expect(m.scheduled, isNull);
    expect(m.pendingRenewal, isNull);
    expect(m.memberStatus, MemberStatus.frozen);
    expect(m.renewNotice, RenewNotice.noPackage);
  });
}
