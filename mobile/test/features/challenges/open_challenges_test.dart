import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/challenges/data/open_challenge_repository.dart';
import 'package:hvp_forging/features/challenges/domain/open_challenge.dart';
import 'package:hvp_forging/features/challenges/presentation/open_challenge_providers.dart';
import 'package:hvp_forging/features/challenges/presentation/open_challenges_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

class _FakeChallenges implements OpenChallengeRepository {
  final queries = <({String? type, int page})>[];

  @override
  Future<void> join(String challengeId) async {}

  @override
  Future<OpenChallengePage> list({String? challengeType, int page = 1}) async {
    queries.add((type: challengeType, page: page));
    return OpenChallengePage(
      page: page,
      totalPages: 1,
      total: 1,
      items: <OpenChallenge>[
        OpenChallenge(
          id: 'challenge-1',
          code: 'DAILY_CHECKIN',
          title: challengeType == 'WEEKLY'
              ? 'Tập đều mỗi tuần'
              : 'Điểm danh mỗi ngày',
          description: 'Hoàn thành mục tiêu để nhận thưởng.',
          challengeType: challengeType ?? 'DAILY',
          context: 'SESSION',
          target: 3,
          rewardDp: 30,
          rewardMarks: 15,
          endsAt: DateTime.utc(2026, 11, 10, 12),
          participationId: 'participation-1',
          participationStatus: 'JOINED',
          progressValue: 1,
        ),
      ],
    );
  }
}

void main() {
  test(
    'CHL-09 repository sends challenge type and maps participation',
    () async {
      final dio = createApiDio(
        config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1',
          tenantCode: 'hvp',
        ),
        tokens: MemoryTokenStore(
          const StoredTokens(
            accessToken: 'member-token',
            refreshToken: 'refresh-token',
          ),
        ),
      );
      final adapter = ScriptedAdapter(
        (_) => okEnvelope(
          <dynamic>[
            <String, dynamic>{
              'id': 'challenge-1',
              'code': 'WEEKLY_BAG',
              'title': 'Bao cát mỗi tuần',
              'challengeType': 'WEEKLY',
              'context': 'SESSION',
              'target': 5,
              'rewardDp': 50,
              'rewardMarks': 25,
              'endsAt': '2026-11-10T12:00:00.000Z',
              'participationId': 'participation-1',
              'participationStatus': 'JOINED',
              'progressValue': 2,
            },
          ],
          meta: <String, dynamic>{
            'page': 1,
            'limit': 20,
            'total': 1,
            'totalPages': 1,
          },
        ),
      );
      dio.httpClientAdapter = adapter;

      final page = await OpenChallengeRepositoryImpl(ApiClient(dio))
          .list(challengeType: 'WEEKLY');

      expect(adapter.requests.single.path, '/me/challenges');
      expect(adapter.requests.single.queryParameters, <String, dynamic>{
        'page': 1,
        'limit': 20,
        'challengeType': 'WEEKLY',
      });
      expect(page.items.single.participationStatus, 'JOINED');
      expect(page.items.single.progressValue, 2);
    },
  );

  test('CHL-09 joins an open Challenge by id', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(accessToken: 'member-token', refreshToken: 'refresh-token')),
    );
    final adapter = ScriptedAdapter((_) => okEnvelope(<String, dynamic>{'id': 'participation-1'}));
    dio.httpClientAdapter = adapter;

    await OpenChallengeRepositoryImpl(ApiClient(dio)).join('challenge-1');

    expect(adapter.requests.single.path, '/me/challenges/challenge-1/join');
    expect(adapter.requests.single.method, 'POST');
  });

  testWidgets('CHL-09 lists open challenges and applies the period filter', (
    tester,
  ) async {
    final repo = _FakeChallenges();
    await pumpHvp(
      tester,
      const OpenChallengesScreen(),
      overrides: [
        currentUserIdProvider.overrideWithValue('member'),
        openChallengeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Điểm danh mỗi ngày'), findsOneWidget);
    expect(find.text('ĐÃ THAM GIA'), findsOneWidget);
    expect(find.text('+30 DP'), findsOneWidget);
    final weekly = find.text('Hằng tuần');
    await tester.ensureVisible(weekly);
    await tester.tap(weekly);
    await tester.pumpAndSettle();
    expect(repo.queries.last, (type: 'WEEKLY', page: 1));
    expect(find.text('Tập đều mỗi tuần'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
