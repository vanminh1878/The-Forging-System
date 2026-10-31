import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/staff/data/staff_dto.dart';
import 'package:hvp_forging/features/staff/data/staff_repository_impl.dart';
import 'package:hvp_forging/features/staff/domain/staff_models.dart';

import '../../helpers/scripted_adapter.dart';

({StaffRepositoryImpl repo, ScriptedAdapter adapter}) build(
    ResponseBody Function(RequestOptions) handler) {
  final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'admin-token', refreshToken: 'refresh')));
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (repo: StaffRepositoryImpl(ApiClient(dio)), adapter: adapter);
}

void main() {
  test(
      'maps optional staff fields, preserves multiple roles and unknown status',
      () {
    final member = staffMemberFromJson(<String, dynamic>{
      'id': '1',
      'fullName': 'Coach Test',
      'roles': <String>['COACH', 'HEAD_COACH'],
      'accountStatus': 'FUTURE_STATUS'
    });
    expect(member.roleLabel, 'Coach · Head Coach');
    expect(member.phone, isNull);
    expect(member.branchId, isNull);
    expect(member.mustChangePassword, isFalse);
    expect(StaffStatus.labelOf(member.accountStatus), 'FUTURE_STATUS');
  });

  test('sends supported filters, tenant header, bearer token, and pagination',
      () async {
    final test = build((_) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': '1',
            'fullName': 'Mai',
            'roles': <String>['COACH'],
            'accountStatus': 'ACTIVE',
            'mustChangePassword': true
          },
        ], meta: <String, dynamic>{
          'page': 2,
          'limit': 20,
          'total': 41,
          'totalPages': 3
        }));
    final result = await test.repo.search(const StaffQuery(
        q: ' Mai ',
        role: StaffRole.coach,
        status: StaffStatus.active,
        branchId: 'q7',
        page: 2));
    final request = test.adapter.requests.single;
    expect(request.path, '/admin/staff');
    expect(request.queryParameters, <String, dynamic>{
      'q': 'Mai',
      'role': 'COACH',
      'status': 'ACTIVE',
      'branchId': 'q7',
      'page': 2,
      'limit': 20
    });
    expect(request.headers['Authorization'], 'Bearer admin-token');
    expect(request.headers['X-Tenant-Code'], 'hvp');
    expect(result.items.single.mustChangePassword, isTrue);
    expect(result.total, 41);
    expect(result.hasMore, isTrue);
  });

  test('omits empty filters instead of sending null or blank parameters',
      () async {
    final test = build((_) => okEnvelope(<dynamic>[], meta: <String, dynamic>{
          'page': 1,
          'limit': 20,
          'total': 0,
          'totalPages': 1
        }));
    final page = await test.repo.search(const StaffQuery(q: '  '));
    expect(test.adapter.requests.single.queryParameters,
        <String, dynamic>{'page': 1, 'limit': 20});
    expect(page.total, 0);
    expect(page.hasMore, isFalse);
  });

  test('query identity includes all filters and search resets pagination', () {
    const original = StaffQuery(
        q: 'test',
        role: StaffRole.coach,
        status: StaffStatus.active,
        branchId: 'q7',
        page: 3);
    final searched = original.withSearch(' new ');
    expect(searched.page, 1);
    expect(searched.role, original.role);
    expect(searched.status, original.status);
    expect(searched.branchId, original.branchId);
    expect(
        searched,
        const StaffQuery(
            q: 'new',
            role: StaffRole.coach,
            status: StaffStatus.active,
            branchId: 'q7'));
    expect(original.withPage(2), isNot(original));
    expect(
        <StaffQuery>{
          searched,
          const StaffQuery(
              q: 'new',
              role: StaffRole.coach,
              status: StaffStatus.active,
              branchId: 'q7')
        }.length,
        1);
  });

  test('loads branch catalogue when BR-01 is available', () async {
    final test = build((_) => okEnvelope(<dynamic>[
          <String, dynamic>{'id': 'q7', 'name': 'HVP Quận 7'}
        ]));
    expect((await test.repo.branches()).single.name, 'HVP Quận 7');
    expect(test.adapter.requests.single.path, '/branches');
  });

  test('falls back on 404 to all staff pages and deduplicates real branch IDs',
      () async {
    final test = build((request) {
      if (request.path == '/branches') {
        return errorEnvelope(404, 'ROUTE_NOT_FOUND', 'Not implemented');
      }
      final page = request.queryParameters['page'] as int;
      return okEnvelope(<dynamic>[
        <String, dynamic>{
          'id': 'staff-$page',
          'fullName': 'Test',
          'roles': <String>['COACH'],
          'branchId': 'q$page',
          'branchName': 'Branch $page'
        },
        <String, dynamic>{
          'id': 'another',
          'branchId': 'q1',
          'branchName': 'Branch 1'
        },
      ], meta: <String, dynamic>{
        'page': page,
        'limit': 100,
        'total': 102,
        'totalPages': 2
      });
    });
    final options = await test.repo.branches();
    expect(options.map((option) => option.id), <String>['q1', 'q2']);
    expect(test.adapter.requests.length, 3);
    expect(test.adapter.requests.last.queryParameters,
        <String, dynamic>{'page': 2, 'limit': 100});
  });

  test('does not mask a branch service outage with fallback data', () async {
    final test =
        build((_) => errorEnvelope(503, 'UNAVAILABLE', 'Service unavailable'));
    await expectLater(
        test.repo.branches(),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
    expect(test.adapter.requests.length, 1);
  });

  test('surfaces authorization failures instead of showing an empty staff list',
      () async {
    final test =
        build((_) => errorEnvelope(403, 'FORBIDDEN', 'Không có quyền'));
    await expectLater(
        test.repo.search(const StaffQuery()),
        throwsA(
            isA<ApiException>().having((e) => e.code, 'code', 'FORBIDDEN')));
  });
}
