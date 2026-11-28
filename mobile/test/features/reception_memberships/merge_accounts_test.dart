import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/member_detail_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'desk_harness.dart';
import 'members_test.dart'
    show detailRoutes, hitJson, membershipJson, profileJson;
import 'renewal_requests_test.dart' show pageMeta;

Map<String, Reply> _routes(
    {List<dynamic> dups = const <dynamic>[], Reply? merge}) {
  final merged = <String>[];
  return <String, Reply>{
    ...detailRoutes(),
    'GET /members/m1/duplicates': (_) =>
        okEnvelope(merged.isEmpty ? dups : <dynamic>[]),
    'GET /members/m9': (_) => okEnvelope(<String, dynamic>{
          ...profileJson(),
          'userId': 'm9',
          'fullName': 'Lan Cũ'
        }),
    'GET /members/m9/membership': (_) => okEnvelope(membershipJson()),
    'GET /members/m9/duplicates': (_) => okEnvelope(<dynamic>[]),
    'POST /admin/members/merge': (o) {
      final reply = merge?.call(o);
      if (reply != null) return reply;
      merged.add('x');
      return jsonResponse(204, <String, dynamic>{});
    },
  };
}

Future<void> _open(WidgetTester tester, Desk desk) async {
  await pumpHvp(tester, const MemberDetailScreen(memberId: 'm1'),
      overrides: desk.overrides);
  await tester.pumpAndSettle();
}

final _dup = hitJson('m9', 'Lan Cũ');

void main() {
  testWidgets('MEM-19 no trigger when there are no duplicates', (tester) async {
    await _open(tester, Desk(_routes()));
    expect(find.textContaining('tài khoản trùng'), findsNothing);
  });

  testWidgets('MEM-19 keeps the account on screen after a confirmation step',
      (tester) async {
    final desk = Desk(_routes(dups: <dynamic>[_dup]));
    await _open(tester, desk);
    expect(find.text('⚠️ 1 TÀI KHOẢN TRÙNG — XEM & GỘP'), findsOneWidget);

    await tester.tap(find.text('⚠️ 1 TÀI KHOẢN TRÙNG — XEM & GỘP'));
    await tester.pumpAndSettle();
    expect(find.text('GỘP TÀI KHOẢN TRÙNG'), findsOneWidget);
    expect(find.text('Lan Cũ'), findsOneWidget);

    await tester.tap(find.text('GỘP VÀO NGUYỄN THỊ LAN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('không thể hoàn tác'), findsOneWidget);
    expect(desk.calls('POST /admin/members/merge'), isEmpty);

    await tester.tap(find.text('XÁC NHẬN GỘP'));
    await tester.pumpAndSettle();
    expect(desk.calls('POST /admin/members/merge').single.data,
        <String, dynamic>{'keepId': 'm1', 'dropId': 'm9'});
    expect(find.text('Đã gộp tài khoản — lịch sử được giữ nguyên.'),
        findsOneWidget);
    expect(find.textContaining('tài khoản trùng'), findsNothing);
  });

  testWidgets('MEM-19 keeping the other account continues on its detail',
      (tester) async {
    final desk = Desk(<String, Reply>{
      ..._routes(dups: <dynamic>[_dup]),
      'GET /members': (_) => okEnvelope(
          <dynamic>[hitJson('m1', 'Nguyễn Thị Lan')],
          meta: pageMeta(1, 1)),
    });
    await pumpDeskApp(tester, desk);
    await tester.tap(find.text('HỌC VIÊN').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lan');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nguyễn Thị Lan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('⚠️ 1 TÀI KHOẢN TRÙNG — XEM & GỘP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lan Cũ'));
    await tester.pump();
    await tester.tap(find.text('GỘP VÀO LAN CŨ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('XÁC NHẬN GỘP'));
    await tester.pumpAndSettle();

    expect(desk.calls('POST /admin/members/merge').single.data,
        <String, dynamic>{'keepId': 'm9', 'dropId': 'm1'});
    expect(desk.calls('GET /members/m9'), isNotEmpty);
    expect(find.text('Lan Cũ'), findsOneWidget);
  });

  testWidgets('MEM-19 shows the API refusal in the confirmation step',
      (tester) async {
    final desk = Desk(_routes(
        dups: <dynamic>[_dup],
        merge: (_) => errorEnvelope(409, 'ALREADY_MERGED',
            'Một trong hai tài khoản đã được gộp trước đó.')));
    await _open(tester, desk);
    await tester.tap(find.text('⚠️ 1 TÀI KHOẢN TRÙNG — XEM & GỘP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lan Cũ'));
    await tester.pump();
    expect(find.text('GỘP VÀO LAN CŨ'), findsOneWidget);
    await tester.tap(find.text('GỘP VÀO LAN CŨ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('XÁC NHẬN GỘP'));
    await tester.pumpAndSettle();
    expect(find.text('Một trong hai tài khoản đã được gộp trước đó.'),
        findsOneWidget);
    expect(desk.calls('POST /admin/members/merge').single.data,
        <String, dynamic>{'keepId': 'm9', 'dropId': 'm1'});

    await tester.tap(find.text('QUAY LẠI'));
    await tester.pumpAndSettle();
    expect(find.text('GỘP VÀO LAN CŨ'), findsOneWidget);
  });
}
