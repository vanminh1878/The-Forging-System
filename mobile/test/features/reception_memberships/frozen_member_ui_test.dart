import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/design/hvp_icons.dart';
import 'package:hvp_forging/features/reception_checkin/domain/member_hit.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/widgets/member_avatar.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/widgets/member_row.dart';

import '../../helpers/test_harness.dart';

MemberHit _member(String status) => MemberHit(
    id: 'm1',
    memberCode: 'HVP-000001',
    fullName: 'Trần Bình',
    status: status,
    phone: '0911000002');

Future<void> _pump(WidgetTester tester, String status,
    {ThemeMode mode = ThemeMode.dark}) async {
  await pumpHvp(
      tester,
      Scaffold(
          body: Padding(
              padding: const EdgeInsets.all(16),
              child: MemberRow(member: _member(status), onTap: () {}))),
      themeMode: mode);
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in <ThemeMode>[ThemeMode.dark, ThemeMode.light]) {
    testWidgets('frozen row: snowflake on the avatar and on the chip ($mode)',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, 'FROZEN', mode: mode);

      expect(find.text('ĐÃ ĐÓNG BĂNG'), findsOneWidget);
      // one snowflake on the avatar badge, one inside the chip
      expect(find.byIcon(HvpIcons.frozen), findsNWidgets(2));
      // screen readers hear it too (the row's label is merged with the badge's)
      expect(find.bySemanticsLabel(RegExp('đã đóng băng')), findsWidgets);
      semantics.dispose();
    });
  }

  testWidgets('active and inactive rows have no snowflake', (tester) async {
    await _pump(tester, 'ACTIVE');
    expect(find.byIcon(HvpIcons.frozen), findsNothing);
    expect(find.text('HOẠT ĐỘNG'), findsOneWidget);

    await _pump(tester, 'INACTIVE');
    expect(find.byIcon(HvpIcons.frozen), findsNothing);
    expect(find.text('KHÔNG HOẠT ĐỘNG'), findsOneWidget);
  });

  testWidgets('MemberAvatar only badges a frozen account', (tester) async {
    await pumpHvp(
        tester,
        const Scaffold(
            body: Column(children: <Widget>[
          MemberAvatar(url: null, name: 'An', size: 46, frozen: false),
          MemberAvatar(url: null, name: 'Bình', size: 56, frozen: true),
        ])));
    expect(find.byIcon(HvpIcons.frozen), findsOneWidget);
  });
}
