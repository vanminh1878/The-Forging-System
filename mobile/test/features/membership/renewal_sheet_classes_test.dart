import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/domain/package_class_option.dart';
import 'package:hvp_forging/features/membership/presentation/providers/membership_providers.dart';
import 'package:hvp_forging/features/membership/presentation/screens/membership_screen.dart';

import '../../helpers/fake_membership_repository.dart';
import '../../helpers/test_harness.dart';

const _packages = <PackageType>[
  PackageType(
      id: 'p1',
      name: 'BOOK II',
      durationDays: 84,
      totalSessions: 36,
      priceVnd: 9800000,
      classCount: 2),
  PackageType(id: 'p2', name: 'Tự do', priceVnd: 1000000),
];

const _open = PackageClassOption(
  id: 'c1',
  name: 'Boxing tối',
  branchName: 'HVP Quận 1',
  coachName: 'Trần Văn B',
  weekdays: <int>[1, 3, 5],
  startTime: '18:30',
  durationMinutes: 60,
  capacity: 20,
  seatsLeft: 3,
);

const _full = PackageClassOption(
  id: 'c2',
  name: 'Boxing sáng',
  branchName: 'HVP Quận 7',
  weekdays: <int>[2, 4],
  startTime: '06:00',
  durationMinutes: 90,
  capacity: 10,
  seatsLeft: 0,
);

Future<FakeMembershipRepository> _show(
  WidgetTester tester, {
  Future<List<PackageClassOption>> Function(String)? classes,
  Future<void> Function(String, String?)? request,
}) async {
  final repo = FakeMembershipRepository(
    () async => const MyMembership(
        memberStatus: MemberStatus.active, renewNotice: RenewNotice.ended),
    packages: () async => _packages,
    request: request ?? (_, __) async {},
    classes: classes ?? (_) async => const <PackageClassOption>[_open, _full],
  );
  await pumpHvp(
    tester,
    const MembershipScreen(),
    overrides: <Override>[
      membershipRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('ĐĂNG KÝ GÓI MỚI'));
  await tester.pumpAndSettle();
  return repo;
}

const _fullEnrolled = PackageClassOption(
  id: 'c4',
  name: 'Lớp đang học',
  branchName: 'HVP Quận 1',
  weekdays: <int>[2],
  startTime: '19:00',
  durationMinutes: 60,
  capacity: 10,
  seatsLeft: 0,
  enrolled: true,
);

HvpButton _btn(WidgetTester tester, String label) =>
    tester.widget<HvpButton>(find.widgetWithText(HvpButton, label));

void main() {
  testWidgets('package with classes: step 2 lists them, send needs a class',
      (tester) async {
    final repo = await _show(tester);
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    // classes are not shown yet and there is no send button on step 1
    expect(find.text('Boxing tối'), findsNothing);
    expect(find.text('GỬI YÊU CẦU GIA HẠN'), findsNothing);
    await tester.tap(find.widgetWithText(HvpButton, 'TIẾP TỤC'));
    await tester.pumpAndSettle();

    expect(find.text('Boxing tối'), findsOneWidget);
    expect(find.text('HVP Quận 1 · HLV Trần Văn B'), findsOneWidget);
    expect(find.text('T2, T4, T6 · 18:30–19:30'), findsOneWidget);
    expect(find.text('Còn 3 chỗ'), findsOneWidget);
    expect(find.text('Hết chỗ'), findsOneWidget);
    expect(_btn(tester, 'GỬI YÊU CẦU GIA HẠN').onPressed, isNull);

    await tester.tap(find.text('Boxing tối'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ghi chú');
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU GIA HẠN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lớp: Boxing tối'), findsOneWidget);
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU'));
    await tester.pumpAndSettle();

    expect(repo.requests.single.packageTypeId, 'p1');
    expect(repo.requests.single.classId, 'c1');
    expect(repo.requests.single.note, 'ghi chú');
    expect(find.text('Đã gửi yêu cầu gia hạn tới lễ tân.'), findsOneWidget);
  });

  testWidgets('a full class the learner attends is selectable and sendable',
      (tester) async {
    final repo = await _show(tester,
        classes: (_) async => const <PackageClassOption>[_full, _fullEnrolled]);
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'TIẾP TỤC'));
    await tester.pumpAndSettle();
    expect(find.text('Đang học lớp này'), findsOneWidget);
    await tester.tap(find.text('Lớp đang học'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU GIA HẠN'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU'));
    await tester.pumpAndSettle();
    expect(repo.requests.single.classId, 'c4');
    expect(repo.classMemberIds.every((m) => m == null), isTrue);
  });

  testWidgets('a full class cannot be selected', (tester) async {
    final repo = await _show(tester);
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'TIẾP TỤC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boxing sáng'));
    await tester.pump();
    expect(_btn(tester, 'GỬI YÊU CẦU GIA HẠN').onPressed, isNull);
    expect(repo.requests, isEmpty);
  });

  testWidgets('package without classes skips the class step', (tester) async {
    final repo = await _show(tester);
    await tester.tap(find.text('Tự do'));
    await tester.pump();
    expect(find.text('TIẾP TỤC'), findsNothing);
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU GIA HẠN'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU'));
    await tester.pumpAndSettle();
    expect(repo.requests.single.packageTypeId, 'p2');
    expect(repo.requests.single.classId, isNull);
    expect(repo.classCalls, 0);
  });

  testWidgets('"Đổi gói" goes back to the package list', (tester) async {
    await _show(tester);
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'TIẾP TỤC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi gói'));
    await tester.pumpAndSettle();
    expect(find.text('Tự do'), findsOneWidget);
    expect(find.text('Boxing tối'), findsNothing);
  });

  testWidgets('CLASS_FULL shows the message, clears the choice and reloads',
      (tester) async {
    final repo = await _show(
      tester,
      request: (_, __) async => throw const ApiException(
          code: 'CLASS_FULL', message: 'Lớp đã đủ sĩ số', statusCode: 409),
    );
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'TIẾP TỤC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boxing tối'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU GIA HẠN'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'GỬI YÊU CẦU'));
    await tester.pumpAndSettle();

    expect(find.text('Lớp đã đủ sĩ số'), findsOneWidget);
    expect(repo.classCalls, 2);
    expect(_btn(tester, 'GỬI YÊU CẦU GIA HẠN').onPressed, isNull);
    expect(find.text('CHỌN GÓI TẬP'), findsOneWidget);
  });

  testWidgets('a package whose classes are all closed shows an empty state',
      (tester) async {
    await _show(tester, classes: (_) async => const <PackageClassOption>[]);
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'TIẾP TỤC'));
    await tester.pumpAndSettle();
    expect(find.text('GÓI NÀY CHƯA CÓ LỚP NÀO ĐANG MỞ'), findsOneWidget);
    expect(_btn(tester, 'GỬI YÊU CẦU GIA HẠN').onPressed, isNull);
  });

  testWidgets('class list error offers a retry', (tester) async {
    var fail = true;
    final repo = await _show(tester, classes: (_) async {
      if (fail) throw const ApiException(code: 'X', message: 'Lỗi mạng');
      return const <PackageClassOption>[_open];
    });
    await tester.tap(find.text('BOOK II'));
    await tester.pump();
    await tester.tap(find.widgetWithText(HvpButton, 'TIẾP TỤC'));
    await tester.pumpAndSettle();
    expect(find.text('Lỗi mạng'), findsOneWidget);
    fail = false;
    await tester.tap(find.widgetWithText(HvpButton, 'THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(repo.classCalls, 2);
    expect(find.text('Boxing tối'), findsOneWidget);
  });
}
