import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/coach_challenges/data/challenge_review_repository.dart';
import 'package:hvp_forging/features/coach_challenges/domain/challenge_review.dart';
import 'package:hvp_forging/features/coach_challenges/presentation/challenge_review_providers.dart';
import 'package:hvp_forging/features/coach_challenges/presentation/challenge_review_tab.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

class _FakeChallengeReviews implements ChallengeReviewRepository {
  int approved = 0;

  @override
  Future<ChallengeReviewPage> list({String? status, String? evidence, String? query, int page = 1}) async => ChallengeReviewPage(
    page: page,
    totalPages: 1,
    total: 1,
    items: <ChallengeReview>[
        const ChallengeReview(
          participationId: 'participation-1',
          challengeTitle: 'Bao cát bền bỉ',
          memberFullName: 'Nguyễn Văn A',
          memberCode: 'HVP0001',
          progressValue: 5,
          target: 5,
          status: 'AWAITING_COACH',
          evidenceUrl: null,
        ),
      ],
  );

  @override
  Future<void> approve(String participationId) async => approved++;

  @override
  Future<void> approveJoin(String participationId) async => approved++;
}

void main() {
  test('CHL-06 lists filtered Challenge participations for the coach', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'coach-token', refreshToken: 'refresh-token')),
    );
    final adapter = ScriptedAdapter(
      (_) => okEnvelope(<dynamic>[
        <String, dynamic>{
          'id': 'participation-1',
          'challengeTitle': 'Bao cát bền bỉ',
          'memberFullName': 'Nguyễn Văn A',
          'memberCode': 'HVP0001',
          'progressValue': 5,
          'target': 5,
          'status': 'AWAITING_COACH',
          'evidenceUrl': 'http://test.local/files/proof.jpg',
        },
      ], meta: <String, dynamic>{'page': 2, 'limit': 20, 'total': 21, 'totalPages': 2}),
    );
    dio.httpClientAdapter = adapter;

    final result = await ChallengeReviewRepositoryImpl(ApiClient(dio)).list(
      status: 'AWAITING_COACH', evidence: 'SUBMITTED', query: 'HVP0001', page: 2,
    );

    expect(adapter.requests.single.path, '/staff/challenges/participations');
    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'status': 'AWAITING_COACH',
      'evidence': 'SUBMITTED',
        'q': 'HVP0001',
        'page': 2,
        'limit': 20,
    });
    expect(result.totalPages, 2);
    expect(result.items.single.challengeTitle, 'Bao cát bền bỉ');
    expect(result.items.single.memberFullName, 'Nguyễn Văn A');
    expect(result.items.single.evidenceUrl, 'http://test.local/files/proof.jpg');
  });

  test('CHL-06 approves the participation by id', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'coach-token', refreshToken: 'refresh-token')),
    );
    final adapter = ScriptedAdapter(
      (_) => okEnvelope(<String, dynamic>{'id': 'participation-1'}),
    );
    dio.httpClientAdapter = adapter;

    await ChallengeReviewRepositoryImpl(ApiClient(dio)).approve('participation-1');

    expect(adapter.requests.single.path,
        '/staff/challenges/participations/participation-1/approve');
  });

  testWidgets('CHL-06 shows the waiting submission for the coach', (tester) async {
    final fake = _FakeChallengeReviews();
    await pumpHvp(
      tester,
      const ChallengeReviewTab(),
      overrides: [
        challengeReviewRepositoryProvider.overrideWithValue(fake),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Duyệt Challenge'), findsOneWidget);
    expect(find.text('Bao cát bền bỉ'), findsOneWidget);
    expect(find.text('Nguyễn Văn A · HVP0001'), findsOneWidget);
    expect(find.text('Tiến độ: 5 / 5'), findsOneWidget);
    expect(find.text('Học viên chưa nộp ảnh minh chứng.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
