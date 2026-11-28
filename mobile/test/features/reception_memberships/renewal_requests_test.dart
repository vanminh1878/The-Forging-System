import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/reception_memberships_tab.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'desk_harness.dart';

Map<String, dynamic> renewalJson(String id, String name,
        {String status = 'PENDING', String? reason}) =>
    <String, dynamic>{
      'id': id,
      'status': status,
      'note': 'Tuần sau đóng tiền',
      'reason': reason,
      'createdAt': '2026-10-24T05:00:00.000Z',
      'member': <String, dynamic>{
        'id': 'm-$id',
        'fullName': name,
        'phone': '0911000001',
        'memberCode': 'HVP000123'
      },
      'desiredPackage': <String, dynamic>{
        'id': 'p1',
        'name': 'BOOK II',
        'priceVnd': 9800000
      },
      'currentMembership': <String, dynamic>{
        'id': 'c1',
        'packageName': 'BOOK I',
        'endDate': '2026-11-30'
      },
    };

Map<String, dynamic> pageMeta(int page, int total) => <String, dynamic>{
      'page': page,
      'limit': 20,
      'total': total,
      'totalPages': (total / 20).ceil()
    };

Future<void> pumpTab(WidgetTester tester, Desk desk) async {
  await pumpHvp(tester, const Scaffold(body: ReceptionMembershipsTab()),
      overrides: desk.overrides);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'MEM-12 lists pending requests with name, phone, package and price',
      (tester) async {
    final desk = Desk(<String, Reply>{
      'GET /renewal-requests': (_) => okEnvelope(
          <dynamic>[renewalJson('r1', 'Nguyễn Văn A')],
          meta: pageMeta(1, 1)),
    });
    await pumpTab(tester, desk);

    expect(desk.calls('GET /renewal-requests').single.queryParameters,
        containsPair('status', 'PENDING'));
    expect(find.text('YÊU CẦU'), findsOneWidget);
    expect(find.text('HỌC VIÊN'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('0911000001 · HVP000123'), findsOneWidget);
    expect(find.text('BOOK II · 9.800.000đ'), findsOneWidget);
    expect(
        find.text('Gói hiện tại: BOOK I · hết hạn 30/11/2026'), findsOneWidget);
  });

  testWidgets('MEM-12 empty pending inbox says so', (tester) async {
    final desk = Desk(<String, Reply>{
      'GET /renewal-requests': (_) =>
          okEnvelope(<dynamic>[], meta: pageMeta(1, 0))
    });
    await pumpTab(tester, desk);
    expect(find.text('Không có yêu cầu gia hạn nào đang chờ.'), findsOneWidget);
  });

  testWidgets('MEM-12 shows the API error with a retry that reloads',
      (tester) async {
    var fail = true;
    final desk = Desk(<String, Reply>{
      'GET /renewal-requests': (_) => fail
          ? errorEnvelope(500, 'INTERNAL', 'Máy chủ lỗi')
          : okEnvelope(<dynamic>[renewalJson('r1', 'Nguyễn Văn A')],
              meta: pageMeta(1, 1)),
    });
    await pumpTab(tester, desk);
    expect(find.text('Nguyễn Văn A'), findsNothing);
    fail = false;
    await tester.tap(find.text('THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
  });

  testWidgets(
      'MEM-12 search and status filter go to the API; paging appends the next page',
      (tester) async {
    final desk = Desk(<String, Reply>{
      'GET /renewal-requests': (o) {
        final q = o.queryParameters;
        if (q['status'] == 'CANCELLED') {
          return okEnvelope(<dynamic>[
            renewalJson('r9', 'Trần Huỷ',
                status: 'CANCELLED', reason: 'Sai gói')
          ], meta: pageMeta(1, 1));
        }
        if (q['q'] == 'lan') {
          return okEnvelope(<dynamic>[renewalJson('r5', 'Lan Anh')],
              meta: pageMeta(1, 1));
        }
        final page = q['page'] as int;
        return okEnvelope(<dynamic>[renewalJson('r$page', 'Người $page')],
            meta: pageMeta(page, 40));
      },
    });
    await pumpTab(tester, desk);

    await tester.tap(find.text('TẢI THÊM'));
    await tester.pumpAndSettle();
    expect(find.text('Người 1'), findsOneWidget);
    expect(find.text('Người 2'), findsOneWidget);
    expect(find.text('TẢI THÊM'), findsNothing);

    await tester.enterText(find.byType(TextField), 'lan');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(desk.calls('GET /renewal-requests').last.queryParameters,
        containsPair('q', 'lan'));
    expect(find.text('Lan Anh'), findsOneWidget);

    await tester.tap(find.text('Đã huỷ'));
    await tester.pumpAndSettle();
    expect(desk.calls('GET /renewal-requests').last.queryParameters,
        containsPair('status', 'CANCELLED'));
    expect(find.text('Lý do huỷ: Sai gói'), findsOneWidget);
  });
}
