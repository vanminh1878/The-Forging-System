import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/utils/time_input.dart';
import 'package:hvp_forging/core/widgets/hvp_time_field.dart';

import '../helpers/test_harness.dart';

String _typed(String raw) => const HmInputFormatter()
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: raw))
    .text;

void main() {
  group('parseHm / formatHm', () {
    test('accepts 24-hour times, with or without the leading zero', () {
      expect(parseHm('00:00'), const TimeOfDay(hour: 0, minute: 0));
      expect(parseHm('6:05'), const TimeOfDay(hour: 6, minute: 5));
      expect(parseHm(' 23:59 '), const TimeOfDay(hour: 23, minute: 59));
      expect(formatHm(const TimeOfDay(hour: 6, minute: 5)), '06:05');
    });

    test('rejects out-of-range, malformed and empty input', () {
      for (final bad in <String?>[
        null,
        '',
        '   ',
        '24:00',
        '12:60',
        '12:5',
        '1230',
        'ab:cd',
        '12:30:00',
        '１２:３０', // full-width digits
        '-1:30',
      ]) {
        expect(parseHm(bad), isNull, reason: '"$bad"');
        expect(validateHm(bad), invalidHmMessage, reason: '"$bad"');
      }
      expect(validateHm('18:30'), isNull);
    });
  });

  group('HmInputFormatter', () {
    test('inserts the colon and caps the length', () {
      expect(_typed('1'), '1');
      expect(_typed('18'), '18');
      expect(_typed('183'), '18:3');
      expect(_typed('1830'), '18:30');
      expect(_typed('183099'), '18:30');
    });

    test('blocks letters, spaces, emoji and symbols', () {
      expect(_typed('ab12'), '12');
      expect(_typed('1 8:3 0'), '18:30');
      expect(_typed('1😀8'), '18');
      expect(_typed('-+*#'), '');
      expect(_typed('Một'), '');
    });

    test('keeps a pasted time and pads a single-digit hour', () {
      expect(_typed('18:30'), '18:30');
      expect(_typed('6:30'), '06:30');
      expect(_typed('6:3099'), '06:30');
    });

    test('deleting the last digit after the colon drops the colon', () {
      expect(_typed('18:'), '18');
    });
  });

  testWidgets('HvpTimeField: typing formats, the clock opens the picker',
      (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await pumpHvp(
      tester,
      Scaffold(
          body: Padding(
              padding: const EdgeInsets.all(16),
              child: HvpTimeField(
                  label: 'Giờ bắt đầu',
                  controller: c,
                  required: true,
                  validator: validateHm))),
      overrides: const <Override>[],
    );

    expect(find.text('Giờ bắt đầu *'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'x1y8z3w0');
    expect(c.text, '18:30');

    await tester.tap(find.bySemanticsLabel('Chọn giờ'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    // initial time is the typed one; confirming keeps it
    await tester.tap(find.text('OK').evaluate().isNotEmpty
        ? find.text('OK')
        : find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(c.text, '18:30');
  });
}
