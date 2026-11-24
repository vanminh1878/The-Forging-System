import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/branch/branch.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_admin_repository.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_input.dart';
import 'package:hvp_forging/features/branch_admin/presentation/providers/branch_admin_providers.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/branch_list_screen.dart';
import 'package:hvp_forging/features/branch_admin/presentation/widgets/branch_form_sheet.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/test_harness.dart';

class _Repo implements BranchAdminRepository {
  List<Branch> branches = <Branch>[
    const Branch(
        id: 'b1',
        code: 'Q1',
        name: 'The Corner',
        openingHours: '06:00 – 21:30',
        latitude: 10.5,
        longitude: 106.6),
  ];
  int listCalls = 0;
  BranchInput? created;
  (String, BranchInput)? updated;
  ApiException? failWith;
  ({String id, bool isActive, String reason})? status;

  @override
  Future<List<Branch>> getBranches() async {
    listCalls++;
    return branches;
  }

  @override
  Future<Branch> create(BranchInput input) async {
    if (failWith != null) throw failWith!;
    created = input;
    branches = <Branch>[
      ...branches,
      Branch(id: 'b2', code: 'CN001', name: input.name)
    ];
    return branches.last;
  }

  @override
  Future<Branch> setActive(String id,
      {required bool isActive, required String reason}) async {
    if (failWith != null) throw failWith!;
    status = (id: id, isActive: isActive, reason: reason);
    branches = <Branch>[
      Branch(id: id, code: 'Q1', name: 'The Corner', isActive: isActive)
    ];
    return branches.first;
  }

  @override
  Future<Branch> update(String id, BranchInput input) async {
    if (failWith != null) throw failWith!;
    updated = (id, input);
    return branches.first;
  }
}

LatLng? _pickerStart;

Future<void> _pump(WidgetTester tester, _Repo repo,
    {LatLng? picked = const LatLng(10.7380, 106.7210)}) async {
  _pickerStart = null;
  await pumpHvp(tester, const BranchListScreen(), overrides: <Override>[
    branchAdminRepositoryProvider.overrideWithValue(repo),
    currentUserIdProvider.overrideWithValue('admin-1'),
    branchMapPickerProvider.overrideWithValue((context, initial) async {
      _pickerStart = initial;
      return picked;
    }),
  ]);
  await tester.pumpAndSettle();
}

final _formSwitch = find.descendant(
    of: find.byType(BranchFormSheet), matching: find.byType(Switch));

Finder get _fields => find.byType(TextFormField);
// Order in the form: name, code, address, open, close, position, radius.
const _name = 0, _code = 1, _address = 2, _open = 3, _close = 4;
const _position = 5, _radius = 6;

Future<void> _openAdd(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Thêm chi nhánh'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, int index) =>
    tester.widget<TextFormField>(_fields.at(index)).controller!.text;

void main() {
  testWidgets('add: code is read-only and pending, name is required',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await _openAdd(tester);

    expect(find.text('Tự động tạo khi lưu'), findsOneWidget);
    expect(tester.widget<TextFormField>(_fields.at(_code)).enabled, isFalse);
    expect(_text(tester, _radius), '100');

    await _submit(tester, 'TẠO CHI NHÁNH');
    expect(repo.created, isNull);
    expect(find.text('Tên chi nhánh gồm 2–100 ký tự.'), findsOneWidget);
    // the first invalid field takes the focus
    final nameEditable = tester.widget<EditableText>(find.descendant(
        of: _fields.at(_name), matching: find.byType(EditableText)));
    expect(nameEditable.focusNode.hasFocus, isTrue);
  });

  testWidgets('add: saves without a code, with hours and the picked position',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await _openAdd(tester);

    await tester.enterText(_fields.at(_name), 'Quận 7');
    await tester.enterText(_fields.at(_open), '0600');
    await tester.enterText(_fields.at(_close), '2130');
    expect(_text(tester, _open), '06:00');
    expect(_text(tester, _close), '21:30');

    await tester.ensureVisible(_fields.at(_position));
    await tester.tap(_fields.at(_position));
    await tester.pumpAndSettle();
    expect(find.text('10.738000, 106.721000'), findsOneWidget);
    expect(_pickerStart, isNull);

    await _submit(tester, 'TẠO CHI NHÁNH');

    expect(repo.created!.code, isNull);
    expect(repo.created!.name, 'Quận 7');
    expect(repo.created!.openingHours, '06:00 – 21:30');
    expect(repo.created!.latitude, 10.738);
    expect(repo.created!.longitude, 106.721);
    expect(repo.created!.geofenceRadiusM, 100);
    expect(repo.listCalls, 2);
    expect(find.text('Quận 7'), findsOneWidget);
    expect(find.text('Đã tạo chi nhánh'), findsOneWidget);
  });

  testWidgets('add: cancelling the map keeps the position empty',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, picked: null);
    await _openAdd(tester);
    await tester.enterText(_fields.at(_name), 'Quận 7');

    await tester.ensureVisible(_fields.at(_position));
    await tester.tap(_fields.at(_position));
    await tester.pumpAndSettle();
    await _submit(tester, 'TẠO CHI NHÁNH');

    expect(repo.created!.latitude, isNull);
    expect(repo.created!.longitude, isNull);
    expect(find.text('Xóa vị trí'), findsNothing);
  });

  testWidgets('hours: letters are blocked, both times needed, close after open',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await _openAdd(tester);
    await tester.enterText(_fields.at(_name), 'Quận 7');

    await tester.enterText(_fields.at(_open), 'ab12cd');
    expect(_text(tester, _open), '12');
    await tester.enterText(_fields.at(_open), '06:00');
    await _submit(tester, 'TẠO CHI NHÁNH');
    expect(find.text('Nhập giờ đóng cửa.'), findsOneWidget);
    expect(repo.created, isNull);

    await tester.enterText(_fields.at(_close), '0559');
    await _submit(tester, 'TẠO CHI NHÁNH');
    expect(find.text('Giờ đóng cửa phải sau giờ mở cửa.'), findsOneWidget);

    await tester.enterText(_fields.at(_close), '0601');
    await _submit(tester, 'TẠO CHI NHÁNH');
    expect(repo.created!.openingHours, '06:00 – 06:01');
  });

  testWidgets('radius: digits only, 10 to 5000', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await _openAdd(tester);
    await tester.enterText(_fields.at(_name), 'Quận 7');

    await tester.enterText(_fields.at(_radius), '1x0y');
    expect(_text(tester, _radius), '10');
    for (final bad in <String>['9', '5001', '']) {
      await tester.enterText(_fields.at(_radius), bad);
      await _submit(tester, 'TẠO CHI NHÁNH');
      expect(find.text('Bán kính từ 10 đến 5000 m.'), findsOneWidget,
          reason: 'radius "$bad"');
      expect(repo.created, isNull);
    }
    await tester.enterText(_fields.at(_radius), '5000');
    await _submit(tester, 'TẠO CHI NHÁNH');
    expect(repo.created!.geofenceRadiusM, 5000);
  });

  testWidgets('name and address stop at their limits', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await _openAdd(tester);

    await tester.enterText(_fields.at(_name), 'A' * 120);
    expect(_text(tester, _name).length, 100);
    await tester.enterText(_fields.at(_address), 'đ' * 300);
    expect(_text(tester, _address).length, 255);
  });

  testWidgets('edit: pre-fills hours and position, never sends the code',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);

    await tester.tap(find.text('The Corner'));
    await tester.pumpAndSettle();
    expect(find.text('SỬA CHI NHÁNH'), findsOneWidget);
    expect(_text(tester, _code), 'Q1');
    expect(tester.widget<TextFormField>(_fields.at(_code)).enabled, isFalse);
    expect(_text(tester, _open), '06:00');
    expect(_text(tester, _close), '21:30');
    expect(find.text('10.500000, 106.600000'), findsOneWidget);

    await tester.enterText(_fields.at(_name), 'Corner 2');
    await _submit(tester, 'LƯU THAY ĐỔI');

    expect(repo.updated!.$1, 'b1');
    expect(repo.updated!.$2.name, 'Corner 2');
    expect(repo.updated!.$2.code, isNull);
    expect(repo.updated!.$2.openingHours, '06:00 – 21:30');
    expect(repo.updated!.$2.latitude, 10.5);
    expect(find.text('Đã lưu thay đổi'), findsOneWidget);
  });

  testWidgets('edit: the map opens on the saved position and it can be cleared',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.tap(find.text('The Corner'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_fields.at(_position));
    await tester.tap(_fields.at(_position));
    await tester.pumpAndSettle();
    expect(_pickerStart, const LatLng(10.5, 106.6));

    await tester.ensureVisible(find.text('Xóa vị trí'));
    await tester.tap(find.text('Xóa vị trí'));
    await tester.pumpAndSettle();
    await _submit(tester, 'LƯU THAY ĐỔI');
    expect(repo.updated!.$2.latitude, isNull);
    expect(repo.updated!.$2.longitude, isNull);
  });

  testWidgets('edit: old free-text hours are kept until new times are picked',
      (tester) async {
    final repo = _Repo()
      ..branches = <Branch>[
        const Branch(
            id: 'b1',
            code: 'Q1',
            name: 'The Corner',
            openingHours: '6h đến 21h'),
      ];
    await _pump(tester, repo);
    await tester.tap(find.text('The Corner').first);
    await tester.pumpAndSettle();

    expect(_text(tester, _open), isEmpty);
    expect(find.textContaining('Giờ đang lưu: 6h đến 21h'), findsOneWidget);
    await _submit(tester, 'LƯU THAY ĐỔI');
    expect(repo.updated!.$2.openingHours, '6h đến 21h');

    await tester.tap(find.text('The Corner').first);
    await tester.pumpAndSettle();
    await tester.enterText(_fields.at(_open), '0700');
    await tester.enterText(_fields.at(_close), '2000');
    await _submit(tester, 'LƯU THAY ĐỔI');
    expect(repo.updated!.$2.openingHours, '07:00 – 20:00');
  });

  testWidgets('API error stays in the form as a banner and keeps the input',
      (tester) async {
    final repo = _Repo()
      ..failWith = const ApiException(
          code: 'SERVER_ERROR', message: 'Lỗi máy chủ', statusCode: 500);
    await _pump(tester, repo);
    await _openAdd(tester);
    await tester.enterText(_fields.at(_name), 'Quận 7');
    await _submit(tester, 'TẠO CHI NHÁNH');

    expect(find.text('Lỗi máy chủ'), findsOneWidget);
    expect(_text(tester, _name), 'Quận 7');
    expect(repo.listCalls, 1);
  });

  testWidgets('the form has no QR print or rotate actions any more',
      (tester) async {
    await _pump(tester, _Repo());
    await tester.tap(find.text('The Corner'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mã QR'), findsNothing);
    expect(find.text('XEM MÃ QR ĐỂ IN'), findsNothing);
    expect(find.text('ĐỔI MÃ QR'), findsNothing);
    expect(find.text('THU HỒI MÃ CHECK-IN'), findsNothing);
  });

  testWidgets('switch: needs a reason, then deactivates and refreshes',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.tap(find.text('The Corner'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_formSwitch);
    await tester.tap(_formSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('NGỪNG HOẠT ĐỘNG').last);
    await tester.pumpAndSettle();
    expect(repo.status, isNull);
    expect(find.text('Lý do gồm 3–500 ký tự.'), findsOneWidget);

    await tester.enterText(
        find.byType(TextFormField).last, 'Đóng cửa sửa chữa');
    await tester.tap(find.text('NGỪNG HOẠT ĐỘNG').last);
    await tester.pumpAndSettle();

    expect(
        repo.status, (id: 'b1', isActive: false, reason: 'Đóng cửa sửa chữa'));
    expect(find.text('Đã ngừng hoạt động chi nhánh'), findsOneWidget);
    expect(find.text('SỬA CHI NHÁNH'), findsNothing);
    expect(repo.listCalls, 2);
  });

  testWidgets('switch: API error stays in the reason sheet', (tester) async {
    final repo = _Repo()
      ..failWith = const ApiException(
          code: 'SERVER_ERROR', message: 'Lỗi máy chủ', statusCode: 500);
    await _pump(tester, repo);
    await tester.tap(find.text('The Corner'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_formSwitch);
    await tester.tap(_formSwitch);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Bảo trì');
    await tester.tap(find.text('NGỪNG HOẠT ĐỘNG').last);
    await tester.pumpAndSettle();

    expect(find.text('Lỗi máy chủ'), findsOneWidget);
    expect(repo.listCalls, 1);
  });
}
