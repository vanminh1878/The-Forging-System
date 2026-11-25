import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/core/widgets/hvp_text_field.dart';
import 'package:hvp_forging/features/admin_challenges/data/admin_challenge_repository.dart';
import 'package:hvp_forging/features/admin_challenges/domain/admin_challenge.dart';
import 'package:hvp_forging/features/admin_challenges/presentation/admin_challenge_form_screen.dart';
import 'package:hvp_forging/features/admin_challenges/presentation/admin_challenge_providers.dart';
import 'package:hvp_forging/features/admin_challenges/presentation/admin_challenges_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

final _sample = AdminChallenge(
  id: 'challenge-1',
  code: 'WEEK-01',
  title: 'Bao cát bền bỉ',
  challengeType: 'WEEKLY',
  context: 'SESSION',
  target: 5,
  rewardDp: 50,
  rewardMarks: 25,
  startsAt: DateTime.utc(2026, 11, 1),
  endsAt: DateTime.utc(2026, 11, 8),
  status: 'DRAFT',
);

class _FakeAdminChallenges implements AdminChallengeRepository {
  int createCalls = 0;
  String? lastStatus;

  @override
  Future<AdminChallengePage> list(
      {String? query,
      String? status,
      String? challengeType,
      String? context,
      int page = 1}) async {
    lastStatus = status;
    return AdminChallengePage(
        items: status == 'CLOSED'
            ? const <AdminChallenge>[]
            : <AdminChallenge>[_sample],
        page: page,
        totalPages: 1,
        total: 1);
  }

  @override
  Future<void> create(ChallengeInput input) async => createCalls++;
  @override
  Future<AdminChallenge> detail(String id) async => _sample;
  @override
  Future<void> setEnabled(String id,
      {required bool enabled, required String reason}) async {}
  @override
  Future<void> update(String id, ChallengeInput input, String reason) async {}
}

void main() {
  test('CHL-16 maps list filters and CHL-17 serializes create input', () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'admin', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter((_) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'challenge-1',
            'code': 'WEEK-01',
            'title': 'Bao cát bền bỉ',
            'challengeType': 'WEEKLY',
            'context': 'SESSION',
            'target': 5,
            'rewardDp': 50,
            'rewardMarks': 25,
            'startsAt': '2026-11-01T00:00:00.000Z',
            'endsAt': '2026-11-08T00:00:00.000Z',
            'status': 'DRAFT',
          }
        ], meta: <String, dynamic>{
          'page': 2,
          'limit': 20,
          'total': 21,
          'totalPages': 2
        }));
    dio.httpClientAdapter = adapter;
    final repo = AdminChallengeRepositoryImpl(ApiClient(dio));
    final page = await repo.list(query: '  week  ', status: 'DRAFT', page: 2);

    expect(page.items.single.code, 'WEEK-01');
    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'page': 2,
      'limit': 20,
      'q': 'week',
      'status': 'DRAFT'
    });
    await repo.create(ChallengeInput(
        code: ' week-02 ',
        title: '  Challenge mới ',
        description: '  Mô tả ',
        challengeType: 'WEEKLY',
        context: 'SESSION',
        target: 5,
        rewardDp: 50,
        rewardMarks: 25,
        startsAt: DateTime(2026, 11, 1, 7),
        endsAt: DateTime(2026, 11, 8, 7)));
    expect(adapter.requests[1].path, '/admin/challenges');
    expect(adapter.requests[1].data, containsPair('code', 'WEEK-02'));
    expect(adapter.requests[1].data, containsPair('title', 'Challenge mới'));
  });

  testWidgets('CHL-16 lists and filters Challenges with an empty state',
      (tester) async {
    final repo = _FakeAdminChallenges();
    await pumpHvp(tester, const AdminChallengesScreen(),
        overrides: [adminChallengeRepositoryProvider.overrideWithValue(repo)]);
    await tester.pumpAndSettle();
    expect(find.text('Bao cát bền bỉ'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    final closedFilter = find.text('Đã đóng');
    await tester.tap(closedFilter);
    await tester.pumpAndSettle();
    expect(repo.lastStatus, 'CLOSED');
    expect(find.text('Bao cát bền bỉ'), findsNothing);
  });

  testWidgets('CHL-17 exposes the required title validator in the create form',
      (tester) async {
    final repo = _FakeAdminChallenges();
    await pumpHvp(tester, const AdminChallengeFormScreen(),
        overrides: [adminChallengeRepositoryProvider.overrideWithValue(repo)]);
    final title = tester.widget<HvpTextField>(find.byType(HvpTextField).first);
    expect(title.validator!(' '), 'Nhập ít nhất 2 ký tự.');
    expect(title.validator!('Thử thách mới'), isNull);
  });
}
