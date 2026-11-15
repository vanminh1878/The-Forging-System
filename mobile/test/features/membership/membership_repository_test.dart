import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
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

  test('lists package types, keeping null limits and price', () async {
    final t = _build((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'p1',
            'name': 'BOOK I',
            'isTrial': false,
            'durationDays': 84,
            'totalSessions': 36,
            'priceVnd': 8900000,
          },
          <String, dynamic>{
            'id': 'p2',
            'name': 'Trial',
            'isTrial': true,
            'durationDays': null,
            'totalSessions': null,
            'priceVnd': null,
          },
        ]));
    final list = await t.repo.listPackageTypes();
    expect(t.adapter.requests.single.path, '/package-types');
    expect(list.first.priceVnd, 8900000);
    expect(list.last.isTrial, isTrue);
    expect(list.last.durationDays, isNull);
    expect(list.last.priceVnd, isNull);
  });

  test('requestRenewal posts the trimmed note, or omits an empty one',
      () async {
    final t = _build((o) => okEnvelope(<String, dynamic>{}, status: 201));
    await t.repo.requestRenewal(packageTypeId: 'p1', note: '  hi ');
    await t.repo.requestRenewal(packageTypeId: 'p1', note: '   ');
    expect(t.adapter.requests.first.path, '/me/renewal-requests');
    expect(t.adapter.requests.first.method, 'POST');
    expect(t.adapter.requests.first.data,
        <String, dynamic>{'packageTypeId': 'p1', 'note': 'hi'});
    expect(
        t.adapter.requests.last.data, <String, dynamic>{'packageTypeId': 'p1'});
  });

  test('a 409 surfaces the API message', () async {
    final t = _build((o) => errorEnvelope(409, 'RENEWAL_PENDING_EXISTS',
        'Bạn đã có một yêu cầu gia hạn đang chờ xử lý. Lễ tân sẽ xử lý sớm.'));
    await expectLater(
      t.repo.requestRenewal(packageTypeId: 'p1'),
      throwsA(isA<ApiException>().having(
          (e) => e.message, 'message', startsWith('Bạn đã có một yêu cầu'))),
    );
  });

  test('lists my renewal requests with status, package and reason', () async {
    final t = _build((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'r1',
            'status': 'CANCELLED',
            'reason': 'Hết gói',
            'createdAt': '2026-10-24T05:00:00.000Z',
            'desiredPackage': <String, dynamic>{
              'id': 'p',
              'name': 'BOOK II',
              'priceVnd': 9800000
            },
          },
          <String, dynamic>{
            'id': 'r2',
            'status': 'PENDING',
            'reason': null,
            'createdAt': '2026-10-25T05:00:00.000Z',
            'desiredPackage': <String, dynamic>{'name': 'BOOK I'},
          },
        ], meta: <String, dynamic>{
          'page': 1,
          'limit': 50,
          'total': 2
        }));
    final list = await t.repo.listMyRenewalRequests();
    expect(t.adapter.requests.single.path, '/me/renewal-requests');
    expect(t.adapter.requests.single.queryParameters['limit'], 50);
    expect(list.first.status, RenewalStatus.cancelled);
    expect(list.first.reason, 'Hết gói');
    expect(list.first.packageName, 'BOOK II');
    expect(list.first.priceVnd, 9800000);
    expect(list.last.status, RenewalStatus.pending);
    expect(list.last.reason, isNull);
    expect(list.last.priceVnd, isNull);
  });

  test('lists package classes with seats left (null = unlimited)', () async {
    final t = _build((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'c1',
            'name': 'Boxing tối',
            'branchId': 'b',
            'branchName': 'HVP Quận 1',
            'coachName': 'Trần Văn B',
            'weekdays': <int>[1, 3, 5],
            'startTime': '18:30',
            'durationMinutes': 60,
            'capacity': 20,
            'seatsLeft': 0,
          },
          <String, dynamic>{
            'id': 'c2',
            'name': 'Sáng',
            'branchName': 'HVP Quận 7',
            'coachName': null,
            'weekdays': <int>[2],
            'startTime': '06:00',
            'durationMinutes': 90,
            'capacity': null,
            'seatsLeft': null,
          },
        ]));
    final list = await t.repo.listPackageClasses('p1');
    expect(t.adapter.requests.single.path, '/package-types/p1/classes');
    expect(list.first.weekdays, <int>[1, 3, 5]);
    expect(list.first.isFull, isTrue);
    expect(list.last.coachName, isNull);
    expect(list.last.seatsLeft, isNull);
    expect(list.last.isFull, isFalse);
  });

  test('package classes: enrolled flag and memberId query only when given',
      () async {
    final t = _build((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'c1',
            'name': 'n',
            'branchName': 'b',
            'weekdays': <int>[1],
            'startTime': '18:30',
            'durationMinutes': 60,
            'seatsLeft': 0,
            'enrolled': true,
          },
          <String, dynamic>{'id': 'c2', 'name': 'm', 'seatsLeft': 1},
        ]));
    final list = await t.repo.listPackageClasses('p1', memberId: 'm9');
    await t.repo.listPackageClasses('p1');
    expect(t.adapter.requests.first.queryParameters['memberId'], 'm9');
    expect(t.adapter.requests.last.queryParameters.containsKey('memberId'),
        isFalse);
    expect(list.first.enrolled, isTrue);
    expect(list.first.isSelectable, isTrue);
    expect(list.last.enrolled, isFalse);
  });

  test('requestRenewal sends classId only when given', () async {
    final t = _build((o) => okEnvelope(<String, dynamic>{}, status: 201));
    await t.repo.requestRenewal(packageTypeId: 'p1', classId: 'c1');
    expect(t.adapter.requests.single.data,
        <String, dynamic>{'packageTypeId': 'p1', 'classId': 'c1'});
  });

  test('CLASS_FULL surfaces its code and message', () async {
    final t =
        _build((o) => errorEnvelope(409, 'CLASS_FULL', 'Lớp đã đủ sĩ số'));
    await expectLater(
      t.repo.requestRenewal(packageTypeId: 'p1', classId: 'c1'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'CLASS_FULL')
          .having((e) => e.message, 'message', 'Lớp đã đủ sĩ số')),
    );
  });

  test('renewal request and pending renewal carry the chosen class', () async {
    const cls = <String, dynamic>{
      'id': 'c1',
      'name': 'Boxing tối',
      'branchName': 'HVP Quận 1',
      'weekdays': <int>[1, 3],
      'startTime': '18:30',
    };
    final t = _build((o) => o.path == '/me/membership'
        ? okEnvelope(<String, dynamic>{
            'memberStatus': 'ACTIVE',
            'renewNotice': 'ENDED',
            'pendingRenewal': <String, dynamic>{
              'packageName': 'BOOK II',
              'createdAt': '2026-10-24T05:00:00.000Z',
              'class': cls,
            },
          })
        : okEnvelope(<dynamic>[
            <String, dynamic>{
              'id': 'r1',
              'status': 'PENDING',
              'desiredPackage': <String, dynamic>{'name': 'BOOK II'},
              'class': cls,
            },
            <String, dynamic>{
              'id': 'r2',
              'status': 'PENDING',
              'desiredPackage': <String, dynamic>{'name': 'BOOK I'},
              'class': null,
            },
          ]));
    final m = await t.repo.getMyMembership();
    expect(m.pendingRenewal!.classInfo!.name, 'Boxing tối');
    final list = await t.repo.listMyRenewalRequests();
    expect(list.first.classInfo!.branchName, 'HVP Quận 1');
    expect(list.first.classInfo!.weekdays, <int>[1, 3]);
    expect(list.last.classInfo, isNull);
  });
}
