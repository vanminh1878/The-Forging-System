import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/reception_gifts/data/staff_redemption_repository_impl.dart';

import '../../helpers/scripted_adapter.dart';

({StaffRedemptionRepositoryImpl repo, ScriptedAdapter adapter}) build(
  ResponseBody Function(RequestOptions) handler,
) {
  final dio = createApiDio(
    config: const AppConfig(
        apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
    tokens: MemoryTokenStore(const StoredTokens(
        accessToken: 'reception-token', refreshToken: 'refresh')),
  );
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (
    repo: StaffRedemptionRepositoryImpl(ApiClient(dio)),
    adapter: adapter
  );
}

void main() {
  test('GFT-09 lists pickup requests by status, query and page', () async {
    final test = build((_) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'x1',
            'redemptionCode': 'ARM-001',
            'memberId': 'u1',
            'memberCode': 'HV1',
            'memberFullName': 'Nguyễn An',
            'rewardId': 'r1',
            'rewardName': 'Găng',
            'rewardSku': 'GLOVE',
            'pickupBranchId': 'b1',
            'pickupBranchName': 'Q1',
            'marksCost': 500,
            'status': 'READY_PICKUP',
            'requestedAt': '2026-11-24T08:00:00.000Z',
          },
        ], meta: <String, dynamic>{
          'page': 2,
          'limit': 20,
          'total': 22,
          'totalPages': 2
        }));

    final page =
        await test.repo.list(status: 'READY_PICKUP', query: ' An ', page: 2);

    expect(test.adapter.requests.single.queryParameters, <String, dynamic>{
      'page': 2,
      'limit': 20,
      'status': 'READY_PICKUP',
      'q': 'An'
    });
    expect([
      page.items.single.redemptionCode,
      page.items.single.marksCost,
      page.page,
      page.totalPages,
    ], [
      'ARM-001',
      500,
      2,
      2
    ]);
  });

  test('GFT-10 sends approve, delivery evidence and rejection reason',
      () async {
    final test = build((_) => okEnvelope(<String, dynamic>{}));

    await test.repo.approve('x1', reason: '  Đã kiểm tra  ');
    await test.repo.deliver('x1',
        reason: '  Đã giao  ', evidenceUrl: ' https://files.test/a.jpg ');
    await test.repo.reject('x1', reason: '  Không còn hàng  ');

    expect(test.adapter.requests.map((request) => request.path), <String>[
      '/staff/armory/redemptions/x1/approve',
      '/staff/armory/redemptions/x1/deliver',
      '/staff/armory/redemptions/x1/reject',
    ]);
    expect(test.adapter.requests[0].data,
        <String, dynamic>{'reason': 'Đã kiểm tra'});
    expect(test.adapter.requests[1].data, <String, dynamic>{
      'reason': 'Đã giao',
      'deliveryEvidenceUrl': 'https://files.test/a.jpg'
    });
    expect(test.adapter.requests[2].data,
        <String, dynamic>{'reason': 'Không còn hàng'});
  });
}
