import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/class_admin/domain/class_models.dart';
import 'package:hvp_forging/features/class_admin/domain/class_rules.dart';
import 'package:hvp_forging/features/class_admin/presentation/widgets/class_form_sheet.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'support.dart';

Future<void> tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(HvpButton));
  await tester.tap(find.byType(HvpButton));
  await tester.pumpAndSettle();
}

void main() {
  test('changesFrom lists only edited fields; weekdays compare by value', () {
    final before = ClassDraft.of(sampleClass);
    expect(before.changesFrom(before), isEmpty);
    final edited = ClassDraft(
      branchId: before.branchId,
      name: 'Boxing tối',
      sessionTypeCode: before.sessionTypeCode,
      weekdays: const <int>[1, 3, 5],
      startTime: before.startTime,
      durationMinutes: before.durationMinutes,
      capacity: null,
      defaultCoachId: before.defaultCoachId,
      isActive: before.isActive,
    );
    expect(edited.changesFrom(before),
        <String, Object?>{'name': 'Boxing tối', 'capacity': null});
  });

  test('validators', () {
    expect(validateClassName('  '), 'Nhập tên lớp.');
    expect(validateStartTime('6:30'), isNotNull);
    expect(validateStartTime('23:59'), isNull);
    expect(validateDuration('0'), isNotNull);
    // blank only means "unlimited" through the switch, never through an empty box
    expect(validateCapacity(''), isNotNull);
    expect(validateCapacity('0'), isNotNull);
    expect(validateCapacity('1'), isNull);
    expect(validateCapacity('1000'), isNull);
    expect(validateCapacity('1001'), isNotNull);
    expect(validateCapacity('-3'), isNotNull);
    expect(validateCapacity('12.5'), isNotNull);
    expect(validateDuration('1'), isNull);
    expect(validateDuration('1440'), isNull);
    expect(validateDuration('1441'), isNotNull);
    expect(validateStartTime('00:00'), isNull);
    expect(validateStartTime('24:00'), isNotNull);
    expect(validateStartTime('18:60'), isNotNull);
    expect(validateStartTime(''), isNotNull);
  });

  test('repository create posts the draft, update patches only changes',
      () async {
    final t = buildRepo(
        (o) => okEnvelope(classJson, status: o.method == 'POST' ? 201 : 200));
    await t.repo.create(ClassDraft.of(sampleClass));
    await t.repo.update('c1', <String, Object?>{'capacity': null});
    expect(t.adapter.requests[0].method, 'POST');
    expect(t.adapter.requests[0].path, '/admin/classes');
    expect((t.adapter.requests[0].data as Map)['weekdays'], <int>[1, 3, 5]);
    expect(t.adapter.requests[1].method, 'PATCH');
    expect(t.adapter.requests[1].path, '/admin/classes/c1');
    expect(t.adapter.requests[1].data, <String, Object?>{'capacity': null});
  });

  group('sheet', () {
    Future<FakeClassRepository> show(WidgetTester tester,
        {ClassSummary? existing, FakeClassRepository? repo}) async {
      final fake = repo ?? FakeClassRepository();
      await pumpHvp(
        tester,
        Scaffold(
            body: Builder(
                builder: (c) => TextButton(
                    onPressed: () => showClassForm(c, existing: existing),
                    child: const Text('open')))),
        overrides: classOverrides(fake),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('empty name shows the error and nothing is sent',
        (tester) async {
      final repo = await show(tester);
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Nhập tên lớp.'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('create sends the draft and toasts', (tester) async {
      final repo = await show(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Boxing sáng');
      await tester.tap(find.text('Chọn chi nhánh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HVP Quận 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T2'));
      await tester.tap(find.text('T4'));
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(repo.created.single.weekdays, <int>[1, 3]);
      expect(repo.created.single.capacity, isNull);
      expect(find.text('Đã tạo lớp.'), findsOneWidget);
    });

    testWidgets('edit sends only the changed field', (tester) async {
      final repo = await show(tester, existing: sampleClass);
      await tester.enterText(find.byType(TextFormField).first, 'Boxing tối');
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(repo.updated.single, <String, Object?>{'name': 'Boxing tối'});
      expect(find.text('Đã cập nhật lớp.'), findsOneWidget);
    });

    Finder field(int i) => find.byType(TextFormField).at(i);
    String text(WidgetTester tester, int i) =>
        tester.widget<TextFormField>(field(i)).controller!.text;
    Future<void> fillValid(WidgetTester tester) async {
      await tester.enterText(field(0), 'Boxing sáng');
      await tester.tap(find.text('Chọn chi nhánh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HVP Quận 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T2'));
    }

    testWidgets(
        'capacity: a new class is unlimited, the box is off until the switch is turned off',
        (tester) async {
      await show(tester);
      expect(tester.widget<TextFormField>(field(3)).enabled, isFalse);
      expect(find.text('Không giới hạn sĩ số'), findsOneWidget);
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field(3)).enabled, isTrue);
    });

    testWidgets('capacity: limited needs a number from 1 to 1000, digits only',
        (tester) async {
      final repo = await show(tester);
      await fillValid(tester);
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(field(3), '12ab');
      expect(text(tester, 3), '12');
      await tester.enterText(field(3), '123456');
      expect(text(tester, 3).length, 4);

      for (final bad in <String>['', '0', '1001']) {
        await tester.enterText(field(3), bad);
        await tapSubmit(tester);
        expect(find.text('Sĩ số từ 1 đến 1000.'), findsOneWidget,
            reason: 'capacity "$bad"');
        expect(repo.created, isEmpty);
      }
      await tester.enterText(field(3), '25');
      await tapSubmit(tester);
      expect(repo.created.single.capacity, 25);
    });

    testWidgets(
        'capacity: switching back to unlimited sends null even with a number typed',
        (tester) async {
      final repo = await show(tester);
      await fillValid(tester);
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.enterText(field(3), '25');
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tapSubmit(tester);
      expect(repo.created.single.capacity, isNull);
    });

    testWidgets(
        'edit: a limited class opens with the switch off and its number',
        (tester) async {
      await show(tester, existing: sampleClass);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
      expect(text(tester, 3), '20');
    });

    testWidgets(
        'time and duration: letters blocked, bad values rejected, first error focused',
        (tester) async {
      final repo = await show(tester);
      await fillValid(tester);

      await tester.enterText(field(1), 'ab1830');
      expect(text(tester, 1), '18:30');
      await tester.enterText(field(2), '9x0');
      expect(text(tester, 2), '90');

      await tester.enterText(field(1), '2460');
      await tapSubmit(tester);
      expect(find.text('Giờ không hợp lệ (HH:mm).'), findsOneWidget);
      expect(repo.created, isEmpty);
      final timeEditable = tester.widget<EditableText>(
          find.descendant(of: field(1), matching: find.byType(EditableText)));
      expect(timeEditable.focusNode.hasFocus, isTrue);

      await tester.enterText(field(1), '1830');
      await tester.enterText(field(2), '0');
      await tapSubmit(tester);
      expect(find.text('Thời lượng từ 1 đến 1440 phút.'), findsOneWidget);
      await tester.enterText(field(2), '1441');
      await tapSubmit(tester);
      expect(find.text('Thời lượng từ 1 đến 1440 phút.'), findsOneWidget);
      await tester.enterText(field(2), '1440');
      await tapSubmit(tester);
      expect(repo.created.single.durationMinutes, 1440);
      expect(repo.created.single.startTime, '18:30');
    });

    testWidgets(
        'name: whitespace only is rejected, 120 characters is the limit and the input is kept',
        (tester) async {
      final repo = await show(tester);
      await tester.enterText(field(0), '    ');
      await tapSubmit(tester);
      expect(find.text('Nhập tên lớp.'), findsOneWidget);
      await tester.enterText(field(0), 'Ñ' * 130);
      expect(text(tester, 0).length, 120);
      await tester.enterText(field(0), 'Lớp 💪 Thể lực');
      await tapSubmit(tester);
      expect(text(tester, 0),
          'Lớp 💪 Thể lực'); // a failed submit keeps what was typed
      expect(repo.created, isEmpty); // branch and weekday still missing
    });

    testWidgets('API error stays in the sheet', (tester) async {
      final repo = FakeClassRepository()
        ..createError = const ApiException(
            code: 'BRANCH_INACTIVE', message: 'Chi nhánh đã ngừng hoạt động');
      await show(tester, existing: null, repo: repo);
      await tester.enterText(find.byType(TextFormField).first, 'X');
      await tester.tap(find.text('Chọn chi nhánh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HVP Quận 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T2'));
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Chi nhánh đã ngừng hoạt động'), findsOneWidget);
    });
  });
}
