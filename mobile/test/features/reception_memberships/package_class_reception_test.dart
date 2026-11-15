import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/reception_memberships/data/dto/renewal_dto.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/member_detail_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'activate_package_test.dart' show typeJson;
import 'desk_harness.dart';
import 'members_test.dart' show detailRoutes;
import 'renewal_requests_test.dart' show pageMeta, pumpTab, renewalJson;

Map<String, dynamic> _class(String id, String name, int? seats,
        {String branch = 'HVP Quận 1'}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'branchId': 'b',
      'branchName': branch,
      'coachName': 'Trần Văn B',
      'weekdays': <int>[1, 3, 5],
      'startTime': '18:30',
      'durationMinutes': 60,
      'capacity': 20,
      'seatsLeft': seats,
    };

const Map<String, dynamic> _chosen = <String, dynamic>{
  'id': 'c1',
  'name': 'Boxing tối',
  'branchName': 'HVP Quận 1',
  'weekdays': <int>[1, 3, 5],
  'startTime': '18:30',
};

Finder _confirm() => find.widgetWithText(HvpButton, 'XÁC NHẬN & KÍCH HOẠT GÓI');

Map<String, Reply> _inbox({
  List<dynamic>? classes,
  Reply? approve,
  Map<String, dynamic>? cls = _chosen,
}) =>
    <String, Reply>{
      'GET /renewal-requests': (_) => okEnvelope(
          <dynamic>[renewalJson('r1', 'Nguyễn Văn A', cls: cls)],
          meta: pageMeta(1, 1)),
      'GET /package-types/p1/classes': (_) => okEnvelope(classes ??
          <dynamic>[
            _class('c1', 'Boxing tối', 3),
            _class('c2', 'Boxing sáng', 5, branch: 'HVP Quận 7'),
            _class('c3', 'Lớp đầy', 0),
          ]),
      'POST /renewal-requests/r1/approve': approve ??
          (_) => okEnvelope(<String, dynamic>{'message': 'Đã duyệt gói.'}),
    };

void main() {
  test('renewalFromJson reads the package id and the chosen class', () {
    final r = renewalFromJson(renewalJson('r1', 'A', cls: _chosen));
    expect(r.packageTypeId, 'p1');
    expect(r.classInfo!.id, 'c1');
    expect(r.classInfo!.weekdays, <int>[1, 3, 5]);
    expect(renewalFromJson(renewalJson('r2', 'B')).classInfo, isNull);
  });

  testWidgets('the inbox card shows the chosen class', (tester) async {
    await pumpTab(tester, Desk(_inbox()));
    expect(find.text('Lớp: Boxing tối · HVP Quận 1 · T2, T4, T6 · 18:30'),
        findsOneWidget);
  });

  testWidgets('approve pre-selects the request class and sends its id',
      (tester) async {
    final desk = Desk(_inbox());
    await pumpTab(tester, desk);
    await tester.tap(find.text('ĐỒNG Ý · ĐÃ THU PHÍ'));
    await tester.pumpAndSettle();
    expect(find.text('Boxing sáng'), findsOneWidget);
    expect(find.text('Hết chỗ'), findsOneWidget);

    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pumpAndSettle();
    expect(desk.calls('POST /renewal-requests/r1/approve').single.data,
        <String, dynamic>{'paymentEvidenceUrl': kEvidenceUrl, 'classId': 'c1'});
    expect(find.text('Đã duyệt gói.'), findsOneWidget);
  });

  testWidgets('staff can change the class before approving', (tester) async {
    final desk = Desk(_inbox());
    await pumpTab(tester, desk);
    await tester.tap(find.text('ĐỒNG Ý · ĐÃ THU PHÍ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boxing sáng'));
    await tester.pump();
    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pumpAndSettle();
    expect(
        (desk.calls('POST /renewal-requests/r1/approve').single.data
            as Map)['classId'],
        'c2');
  });

  testWidgets(
      'a full pre-selected class blocks approval until another is picked',
      (tester) async {
    final desk = Desk(_inbox(classes: <dynamic>[
      _class('c1', 'Boxing tối', 0),
      _class('c2', 'Boxing sáng', 5),
    ]));
    await pumpTab(tester, desk);
    await tester.tap(find.text('ĐỒNG Ý · ĐÃ THU PHÍ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    expect(tester.widget<HvpButton>(_confirm()).onPressed, isNull);
    await tester.tap(find.text('Boxing sáng'));
    await tester.pump();
    expect(tester.widget<HvpButton>(_confirm()).onPressed, isNotNull);
  });

  testWidgets('CLASS_FULL on approve shows the message and reloads the classes',
      (tester) async {
    final desk = Desk(_inbox(
        approve: (_) => errorEnvelope(409, 'CLASS_FULL', 'Lớp đã đủ sĩ số')));
    await pumpTab(tester, desk);
    await tester.tap(find.text('ĐỒNG Ý · ĐÃ THU PHÍ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pumpAndSettle();
    expect(find.text('Lớp đã đủ sĩ số'), findsOneWidget);
    expect(desk.calls('GET /package-types/p1/classes'), hasLength(2));
    expect(tester.widget<HvpButton>(_confirm()).onPressed, isNull);
  });

  testWidgets('manual activation: package with classes needs a class',
      (tester) async {
    final desk = Desk(<String, Reply>{
      ...detailRoutes(),
      'GET /package-types': (_) => okEnvelope(<dynamic>[
            <String, dynamic>{...typeJson('p1', 'BOOK I'), 'classCount': 2},
          ]),
      'GET /package-types/p1/classes': (_) => okEnvelope(<dynamic>[
            _class('c1', 'Boxing tối', 3),
            _class('c2', 'Boxing sáng', 5),
          ]),
      'POST /members/m1/memberships': (_) => okEnvelope(<String, dynamic>{
            'message': 'Đã kích hoạt BOOK I.',
            'enrollment': <String, dynamic>{'classId': 'c2'}
          }, status: 201),
    });
    await pumpHvp(tester, const MemberDetailScreen(memberId: 'm1'),
        overrides: desk.overrides);
    await tester.pumpAndSettle();
    await tester.tap(find.text('KÍCH HOẠT / GIA HẠN GÓI'));
    await tester.pumpAndSettle();
    expect(find.text('2 lớp để chọn'), findsOneWidget);
    await tester.tap(find.text('BOOK I').last);
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'TIẾP TỤC'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    expect(tester.widget<HvpButton>(_confirm()).onPressed, isNull);
    await tester.tap(find.text('Boxing sáng'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pumpAndSettle();

    expect(
        desk.calls('POST /members/m1/memberships').single.data,
        <String, dynamic>{
          'packageTypeId': 'p1',
          'classId': 'c2',
          'paymentEvidenceUrl': kEvidenceUrl
        });
    expect(find.text('Đã kích hoạt BOOK I.'), findsOneWidget);
  });

  test('PackageType.hasClasses follows classCount', () {
    expect(const PackageType(id: 'a', name: 'a', classCount: 1).hasClasses,
        isTrue);
    expect(const PackageType(id: 'a', name: 'a').hasClasses, isFalse);
  });
}
