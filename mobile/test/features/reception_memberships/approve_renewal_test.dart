import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';

import '../../helpers/scripted_adapter.dart';
import 'desk_harness.dart';
import 'renewal_requests_test.dart';

Map<String, Reply> _routes({Reply? approve}) {
  var handled = false;
  return <String, Reply>{
    'GET /renewal-requests': (_) => okEnvelope(
        handled ? <dynamic>[] : <dynamic>[renewalJson('r1', 'Nguyễn Văn A')],
        meta: pageMeta(1, handled ? 0 : 1)),
    'GET /package-types/p1/classes': (_) => okEnvelope(<dynamic>[]),
    'POST /renewal-requests/r1/approve': (o) {
      handled = true;
      return approve?.call(o) ??
          okEnvelope(<String, dynamic>{
            'mode': 'ACTIVATED',
            'message': 'Đã kích hoạt gói BOOK II.'
          });
    },
  };
}

Finder _confirm() => find.widgetWithText(HvpButton, 'XÁC NHẬN & KÍCH HOẠT GÓI');

void main() {
  testWidgets(
      'MEM-13 approve needs the photo, sends its URL, toasts the message and reloads',
      (tester) async {
    final desk = Desk(_routes());
    await pumpTab(tester, desk);

    await tester.tap(find.text('ĐỒNG Ý · ĐÃ THU PHÍ'));
    await tester.pumpAndSettle();
    expect(find.text('XÁC NHẬN ĐÃ THU PHÍ'), findsOneWidget);
    expect(find.text('Nguyễn Văn A · BOOK II · 9.800.000đ'), findsOneWidget);
    expect(tester.widget<HvpButton>(_confirm()).onPressed, isNull);

    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pumpAndSettle();

    expect(desk.calls('POST /renewal-requests/r1/approve').single.data,
        <String, dynamic>{'paymentEvidenceUrl': kEvidenceUrl});
    expect(find.text('Đã kích hoạt gói BOOK II.'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsNothing);
    expect(find.text('Không có yêu cầu gia hạn nào đang chờ.'), findsOneWidget);
  });

  testWidgets(
      'MEM-13 shows the API error in the modal and reloads the inbox when already handled',
      (tester) async {
    final desk = Desk(_routes(
        approve: (_) => errorEnvelope(
            409, 'RENEWAL_ALREADY_HANDLED', 'Yêu cầu này đã được xử lý.')));
    await pumpTab(tester, desk);

    await tester.tap(find.text('ĐỒNG Ý · ĐÃ THU PHÍ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu này đã được xử lý.'), findsOneWidget);
    expect(desk.calls('GET /renewal-requests'), hasLength(2));
  });

  testWidgets('approved requests offer no actions', (tester) async {
    final desk = Desk(<String, Reply>{
      'GET /renewal-requests': (_) => okEnvelope(
          <dynamic>[renewalJson('r2', 'Trần B', status: 'COMPLETED')],
          meta: pageMeta(1, 1)),
    });
    await pumpTab(tester, desk);
    await tester.tap(find.text('Đã gia hạn'));
    await tester.pumpAndSettle();
    expect(find.text('Trần B'), findsOneWidget);
    expect(find.byType(HvpButton), findsNothing);
  });
}
