import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/reception_memberships/domain/phone_rules.dart';

import '../../helpers/scripted_adapter.dart';
import 'desk_harness.dart';
import 'members_test.dart'
    show detailRoutes, hitJson, membershipJson, openMembersTab, profileJson;
import 'renewal_requests_test.dart' show pageMeta;

Map<String, Reply> _routes(
        {List<dynamic> found = const <dynamic>[], Reply? create}) =>
    <String, Reply>{
      ...detailRoutes(),
      'GET /members': (_) => okEnvelope(found, meta: pageMeta(1, found.length)),
      'GET /members/new1': (_) => okEnvelope(<String, dynamic>{
            ...profileJson(),
            'userId': 'new1',
            'fullName': 'Lê Mới'
          }),
      'GET /members/new1/membership': (_) =>
          okEnvelope(membershipJson(current: false)),
      'POST /members': create ??
          (_) => okEnvelope(<String, dynamic>{
                'userId': 'new1',
                'temporaryPassword': 'x7k2pa1'
              }, status: 201),
    };

Future<void> _openForm(WidgetTester tester, Desk desk) async {
  await pumpDeskApp(tester, desk);
  await openMembersTab(tester);
  await tester.tap(find.text('TẠO HỌC VIÊN MỚI'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester,
    {String phone = '', String name = ''}) async {
  await tester.enterText(find.byType(TextField).at(1), phone);
  await tester.enterText(find.byType(TextField).at(2), name);
  await tester.tap(find.text('TRA CỨU & TẠO'));
  await tester.pumpAndSettle();
}

void main() {
  test('phones compare in their local form', () {
    expect(normalizePhone('+84 912-345 678'), '0912345678');
    expect(samePhone('0912345678', '+84912345678'), isTrue);
    expect(samePhone('0912345678', '0912345679'), isFalse);
    expect(samePhone(null, '0912345678'), isFalse);
  });

  testWidgets('MEM-17 an exact phone match blocks creation and names the owner',
      (tester) async {
    final desk =
        Desk(_routes(found: <dynamic>[hitJson('m1', 'Nguyễn Thị Lan')]));
    await _openForm(tester, desk);
    await _fill(tester, phone: '+84 912 345 678', name: 'Người khác');

    expect(desk.calls('GET /members').last.queryParameters,
        containsPair('q', '0912345678'));
    expect(find.text('SĐT đã tồn tại: Nguyễn Thị Lan — không tạo mới.'),
        findsOneWidget);
    expect(desk.calls('POST /members'), isEmpty);
  });

  testWidgets(
      'MEM-17 a partial match does not block; creates, shows the password once, opens the learner',
      (tester) async {
    final desk =
        Desk(_routes(found: <dynamic>[hitJson('m1', 'Nguyễn Thị Lan')]));
    await _openForm(tester, desk);
    await _fill(tester, phone: '091234567', name: '  Lê Mới ');

    expect(desk.calls('POST /members').single.data,
        <String, dynamic>{'fullName': 'Lê Mới', 'phone': '091234567'});
    expect(find.text('Đã tạo tài khoản mới (chưa trùng SĐT).'), findsOneWidget);
    expect(find.text('x7k2pa1'), findsOneWidget);

    await tester.tap(find.text('ĐÃ LƯU MẬT KHẨU'));
    await tester.pumpAndSettle();
    expect(find.text('x7k2pa1'), findsNothing);
    expect(find.text('Lê Mới'), findsOneWidget); // the new learner's detail
  });

  testWidgets('MEM-17 asks for the name and shows the API error',
      (tester) async {
    final desk = Desk(_routes(
        create: (_) => errorEnvelope(
            409, 'PHONE_TAKEN', 'Số điện thoại này đã được đăng ký.')));
    await _openForm(tester, desk);
    await _fill(tester, phone: '091234567', name: '');
    expect(find.text('Vui lòng nhập họ tên.'), findsOneWidget);
    expect(
        desk
            .calls('GET /members')
            .where((o) => o.queryParameters.containsKey('q')),
        isEmpty); // the phone lookup did not run

    await _fill(tester, phone: '091234567', name: 'Lê Mới');
    expect(find.text('Số điện thoại này đã được đăng ký.'), findsOneWidget);
  });
}
