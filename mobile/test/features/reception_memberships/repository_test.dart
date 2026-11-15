import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/reception_memberships/data/reception_memberships_api.dart';
import 'package:hvp_forging/features/reception_memberships/data/reception_memberships_repository_impl.dart';

import '../../helpers/scripted_adapter.dart';
import 'desk_harness.dart';
import 'renewal_requests_test.dart' show renewalJson;

void main() {
  late Desk desk;
  late ReceptionMembershipsRepositoryImpl repo;

  void boot(Map<String, Reply> routes) {
    desk = Desk(routes);
    repo =
        ReceptionMembershipsRepositoryImpl(ReceptionMembershipsApi(desk.api));
  }

  test('MEM-12 renewals sends status, q and paging and maps the page',
      () async {
    boot(<String, Reply>{
      'GET /renewal-requests': (_) => okEnvelope(<dynamic>[
            renewalJson('r1', 'Nguyễn Văn A')
          ], meta: <String, dynamic>{
            'page': 1,
            'limit': 20,
            'total': 45,
            'totalPages': 3
          }),
    });
    final page = await repo.renewals(q: 'an', page: 1);
    expect(
        desk.calls('GET /renewal-requests').single.queryParameters,
        <String, dynamic>{
          'status': 'PENDING',
          'page': 1,
          'limit': 20,
          'q': 'an'
        });
    expect(page.hasMore, isTrue);
    final r = page.items.single;
    expect([r.id, r.memberName, r.packageName, r.priceVnd, r.currentEndDate],
        ['r1', 'Nguyễn Văn A', 'BOOK II', 9800000, '2026-11-30']);
  });

  test('MEM-13 approveRenewal posts the evidence URL and returns the message',
      () async {
    boot(<String, Reply>{
      'POST /renewal-requests/r1/approve': (_) =>
          okEnvelope(<String, dynamic>{'message': 'Xong'}),
    });
    expect(await repo.approveRenewal('r1', evidenceUrl: 'http://x/files/a.jpg'),
        'Xong');
    expect(desk.calls('POST /renewal-requests/r1/approve').single.data,
        <String, dynamic>{'paymentEvidenceUrl': 'http://x/files/a.jpg'});
  });

  test('approveRenewal and activateMembership send classId when given',
      () async {
    boot(<String, Reply>{
      'POST /renewal-requests/r1/approve': (_) =>
          okEnvelope(<String, dynamic>{'message': 'Xong'}),
      'POST /members/m1/memberships': (_) =>
          okEnvelope(<String, dynamic>{'message': 'Xong'}, status: 201),
    });
    await repo.approveRenewal('r1',
        evidenceUrl: 'http://x/files/a.jpg', classId: 'c1');
    await repo.activateMembership('m1',
        packageTypeId: 'p1',
        evidenceUrl: 'http://x/files/a.jpg',
        classId: 'c2');
    expect(
        desk.calls('POST /renewal-requests/r1/approve').single.data,
        <String, dynamic>{
          'paymentEvidenceUrl': 'http://x/files/a.jpg',
          'classId': 'c1'
        });
    expect(
        desk.calls('POST /members/m1/memberships').single.data,
        <String, dynamic>{
          'packageTypeId': 'p1',
          'classId': 'c2',
          'paymentEvidenceUrl': 'http://x/files/a.jpg'
        });
  });

  test('MEM-14 cancel calls post the reason to the request and the package',
      () async {
    boot(<String, Reply>{
      'POST /renewal-requests/r1/cancel': (_) =>
          okEnvelope(<String, dynamic>{'id': 'r1'}),
      'POST /memberships/ms1/cancel': (_) =>
          okEnvelope(<String, dynamic>{'membership': <String, dynamic>{}}),
    });
    await repo.cancelRenewal('r1', reason: 'Sai gói');
    await repo.cancelMembership('ms1', reason: 'Học viên xin huỷ');
    expect(desk.calls('POST /renewal-requests/r1/cancel').single.data,
        <String, dynamic>{'reason': 'Sai gói'});
    expect(desk.calls('POST /memberships/ms1/cancel').single.data,
        <String, dynamic>{'reason': 'Học viên xin huỷ'});
  });

  test(
      'MEM-16 packageTypes maps nulls and activateMembership posts package and photo',
      () async {
    boot(<String, Reply>{
      'GET /package-types': (_) => okEnvelope(<dynamic>[
            <String, dynamic>{
              'id': 'p1',
              'name': 'Group',
              'isTrial': false,
              'priceVnd': null,
              'durationDays': null,
              'totalSessions': null
            },
          ]),
      'POST /members/m1/memberships': (_) =>
          okEnvelope(<String, dynamic>{'message': 'Xong'}, status: 201),
    });
    final p = (await repo.packageTypes()).single;
    expect([p.priceVnd, p.durationDays, p.totalSessions], [null, null, null]);
    expect(
        await repo.activateMembership('m1',
            packageTypeId: 'p1', evidenceUrl: 'http://x/files/a.jpg'),
        'Xong');
    expect(
        desk.calls('POST /members/m1/memberships').single.data,
        <String, dynamic>{
          'packageTypeId': 'p1',
          'paymentEvidenceUrl': 'http://x/files/a.jpg'
        });
  });

  test(
      'MEM-17 createMember posts name and phone and reads the one-time password',
      () async {
    boot(<String, Reply>{
      'POST /members': (_) => okEnvelope(
          <String, dynamic>{'userId': 'u1', 'temporaryPassword': 'abc12a1'},
          status: 201),
    });
    final created =
        await repo.createMember(fullName: 'Lê Mới', phone: '0912345678');
    expect([created.id, created.temporaryPassword], ['u1', 'abc12a1']);
    expect(desk.calls('POST /members').single.data,
        <String, dynamic>{'fullName': 'Lê Mới', 'phone': '0912345678'});
  });

  test('MEM-18 changeStatus posts the status and reason (204 answer)',
      () async {
    boot(<String, Reply>{
      'POST /members/m1/status': (_) => jsonResponse(204, <String, dynamic>{})
    });
    await repo.changeStatus('m1', status: 'FROZEN', reason: 'Đi công tác');
    expect(desk.calls('POST /members/m1/status').single.data,
        <String, dynamic>{'status': 'FROZEN', 'reason': 'Đi công tác'});
  });

  test(
      'MEM-19 duplicates maps the accounts and mergeMembers posts keep and drop',
      () async {
    boot(<String, Reply>{
      'GET /members/m1/duplicates': (_) => okEnvelope(<dynamic>[
            <String, dynamic>{
              'userId': 'm9',
              'memberCode': 'HVP9',
              'fullName': 'Lan Cũ',
              'phone': '0912345678',
              'status': 'FROZEN'
            },
          ]),
      'POST /admin/members/merge': (_) =>
          jsonResponse(204, <String, dynamic>{}),
    });
    final dup = (await repo.duplicates('m1')).single;
    expect([dup.id, dup.fullName, dup.status], ['m9', 'Lan Cũ', 'FROZEN']);
    await repo.mergeMembers(keepId: 'm1', dropId: 'm9');
    expect(desk.calls('POST /admin/members/merge').single.data,
        <String, dynamic>{'keepId': 'm1', 'dropId': 'm9'});
  });
}
