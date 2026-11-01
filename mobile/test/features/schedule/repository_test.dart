import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/schedule/data/schedule_api.dart';
import 'package:hvp_forging/features/schedule/data/schedule_repository_impl.dart';
import 'package:hvp_forging/features/schedule/domain/schedule_models.dart';
import 'package:hvp_forging/features/schedule/domain/schedule_query.dart';

import '../../helpers/scripted_adapter.dart';

const AppConfig _config =
    AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

({ScheduleRepositoryImpl repo, ScriptedAdapter adapter}) _build(
    ResponseBody Function(RequestOptions) handler) {
  final dio = createApiDio(
    config: _config,
    tokens: MemoryTokenStore(
        const StoredTokens(accessToken: 'a', refreshToken: 'r')),
  );
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (
    repo: ScheduleRepositoryImpl(ScheduleApi(ApiClient(dio))),
    adapter: adapter
  );
}

final ScheduleQuery _week = ScheduleQuery(
    view: ScheduleView.week, anchorDate: DateTime.utc(2026, 3, 4));

void main() {
  test(
      'getSchedule sends view and date, omits unset filters, parses items and meta',
      () async {
    final t = _build((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'sessionId': 's1',
            'classId': null,
            'title': null,
            'sessionType': 'PT',
            'isExam': true,
            'startsAt': '2026-03-04T11:00:00.000Z',
            'endsAt': '2026-03-04T12:30:00.000Z',
            'date': '2026-03-04',
            'isToday': true,
            'branch': <String, dynamic>{'id': 'b1', 'name': 'The Corner'},
            'coach': null,
            'status': 'AWAITING_COACH',
            'checkinAt': '2026-03-04T10:58:00.000Z',
            'completionPercent': 80,
          },
        ], meta: <String, dynamic>{
          'view': 'week',
          'from': '2026-03-02',
          'to': '2026-03-08'
        }));

    final result = await t.repo.getSchedule(_week);

    final request = t.adapter.requests.single;
    expect(request.path, '/me/schedule');
    expect(request.queryParameters,
        <String, dynamic>{'view': 'week', 'date': '2026-03-04'});
    expect(result.from, '2026-03-02');
    expect(result.to, '2026-03-08');
    final item = result.items.single;
    expect(item.sessionType, SessionType.pt);
    expect(item.isExam, isTrue);
    expect(item.title, isNull);
    expect(item.coachName, isNull);
    expect(item.branchName, 'The Corner');
    expect(item.status, SessionStatus.awaitingCoach);
    expect(item.completionPercent, 80);
    expect(item.checkinAt, isNotNull);
  });
}
