import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/challenges/data/current_challenge_repository.dart';
import 'package:hvp_forging/features/challenges/domain/current_challenge.dart';
import 'package:hvp_forging/features/challenges/presentation/current_challenge_providers.dart';
import 'package:hvp_forging/features/challenges/presentation/current_challenges_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

class _FakeCurrentChallenges implements CurrentChallengeRepository {
  @override
  Future<List<CurrentChallenge>> list() async => <CurrentChallenge>[
        CurrentChallenge(
          id: 'challenge-1',
          participationId: 'participation-1',
          title: 'Bao cát bền bỉ',
          challengeType: 'WEEKLY',
          target: 5,
          rewardDp: 50,
          rewardMarks: 25,
          endsAt: DateTime.utc(2026, 11, 10, 12),
          participationStatus: 'JOINED',
          progressValue: 2,
        ),
      ];

  @override
  Future<void> submitEvidence(String challengeId, String evidenceUrl) async {}
}

void main() {
  test('CHL-10 maps only challenges the learner has joined', () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'member-token', refreshToken: 'refresh-token')),
    );
    final adapter = ScriptedAdapter(
      (_) => okEnvelope(<dynamic>[
        <String, dynamic>{
          'id': 'challenge-joined',
          'title': 'Bao cát bền bỉ',
          'description': 'Hoàn thành năm buổi tập.',
          'challengeType': 'WEEKLY',
          'target': 5,
          'rewardDp': 50,
          'rewardMarks': 25,
          'endsAt': '2026-11-10T12:00:00.000Z',
          'participationId': 'participation-1',
          'participationStatus': 'JOINED',
          'progressValue': 2,
        },
        <String, dynamic>{
          'id': 'challenge-unjoined',
          'title': 'Chưa tham gia',
          'challengeType': 'DAILY',
          'target': 1,
          'rewardDp': 10,
          'rewardMarks': 5,
          'endsAt': '2026-11-10T12:00:00.000Z',
          'participationId': null,
          'participationStatus': null,
          'progressValue': null,
        },
      ]),
    );
    dio.httpClientAdapter = adapter;

    final items = await CurrentChallengeRepositoryImpl(ApiClient(dio)).list();

    expect(adapter.requests.single.path, '/me/challenges');
    expect(adapter.requests.single.queryParameters,
        <String, dynamic>{'page': 1, 'limit': 100});
    expect(items, hasLength(1));
    expect(items.single.progressValue, 2);
    expect(items.single.description, 'Hoàn thành năm buổi tập.');
    expect(items.single.progress, closeTo(0.4, 0.001));
  });

  testWidgets('CHL-10 shows the progress, deadline and rewards card',
      (tester) async {
    await pumpHvp(
      tester,
      const CurrentChallengesScreen(),
      overrides: [
        currentUserIdProvider.overrideWithValue('member'),
        currentChallengeRepositoryProvider
            .overrideWithValue(_FakeCurrentChallenges()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Bao cát bền bỉ'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('+50 DP'), findsOneWidget);
    expect(find.text('+25 Marks'), findsOneWidget);
    expect(find.textContaining('Hạn: 10/11/2026 19:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('CHL-06 posts the evidence URL for the selected challenge', () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'member-token', refreshToken: 'refresh-token')),
    );
    final adapter = ScriptedAdapter(
      (_) => okEnvelope(<String, dynamic>{'id': 'participation-1'}),
    );
    dio.httpClientAdapter = adapter;

    await CurrentChallengeRepositoryImpl(ApiClient(dio))
        .submitEvidence('challenge-1', 'http://test.local/files/proof.jpg');

    expect(adapter.requests.single.path, '/me/challenges/challenge-1/evidence');
    expect(adapter.requests.single.data,
        <String, dynamic>{'evidenceUrl': 'http://test.local/files/proof.jpg'});
  });

  testWidgets('CHL-06 lets a joined learner open the evidence sheet',
      (tester) async {
    await pumpHvp(
      tester,
      const CurrentChallengesScreen(),
      overrides: [
        currentUserIdProvider.overrideWithValue('member'),
        currentChallengeRepositoryProvider
            .overrideWithValue(_AwaitingCoachChallenges()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('ĐÃ THAM GIA'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('YÊU CẦU HOÀN THÀNH'), 120);
    await tester.tap(find.text('YÊU CẦU HOÀN THÀNH'));
    await tester.pumpAndSettle();

    expect(find.text('GỬI YÊU CẦU HOÀN THÀNH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CHL-10 explains attendance progress without an evidence CTA',
      (tester) async {
    final challenge = CurrentChallenge(
      id: 'challenge-attendance',
      participationId: 'participation-attendance',
      title: 'Đi tập đều',
      challengeType: 'WEEKLY',
      target: 5,
      rewardDp: 50,
      rewardMarks: 25,
      endsAt: DateTime.utc(2026, 11, 10, 12),
      participationStatus: 'JOINED',
      progressValue: 2,
      completionMethod: 'ATTENDANCE',
    );

    await pumpHvp(tester, CurrentChallengeCard(challenge: challenge));

    expect(find.text('Tiến độ tự động tăng khi điểm danh buổi tập hợp lệ.'),
        findsOneWidget);
    expect(find.text('YÊU CẦU HOÀN THÀNH'), findsNothing);
  });
}

class _AwaitingCoachChallenges implements CurrentChallengeRepository {
  @override
  Future<List<CurrentChallenge>> list() async => <CurrentChallenge>[
        CurrentChallenge(
          id: 'challenge-1',
          participationId: 'participation-1',
          title: 'Bao cát bền bỉ',
          challengeType: 'WEEKLY',
          target: 5,
          rewardDp: 50,
          rewardMarks: 25,
          endsAt: DateTime.utc(2026, 11, 10, 12),
          participationStatus: 'JOINED',
          progressValue: 5,
        ),
      ];

  @override
  Future<void> submitEvidence(String challengeId, String evidenceUrl) async {}
}
