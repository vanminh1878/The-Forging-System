import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/utils/json_utils.dart';

void main() {
  test('intOf accepts ints, doubles and numeric strings (Postgres bigint)', () {
    final j = <String, dynamic>{'a': 5, 'b': 4.6, 'c': '120', 'd': 'x', 'e': null};
    expect(intOf(j, 'a'), 5);
    expect(intOf(j, 'b'), 5);
    expect(intOf(j, 'c'), 120);
    expect(intOf(j, 'd', 7), 7);
    expect(intOf(j, 'e', 9), 9);
    expect(intOf(j, 'missing'), 0);
  });

  test('str and strOrNull', () {
    final j = <String, dynamic>{'a': 'x', 'b': 3, 'c': '', 'd': null};
    expect(str(j, 'a'), 'x');
    expect(str(j, 'b'), '3');
    expect(str(j, 'd', 'fallback'), 'fallback');
    expect(strOrNull(j, 'c'), isNull);
    expect(strOrNull(j, 'd'), isNull);
    expect(strOrNull(j, 'a'), 'x');
  });

  test('boolOf and doubleOf', () {
    final j = <String, dynamic>{'t': true, 's': 'true', 'n': 2, 'd': '1.5'};
    expect(boolOf(j, 't'), isTrue);
    expect(boolOf(j, 's'), isTrue);
    expect(boolOf(j, 'n'), isFalse);
    expect(doubleOf(j, 'n'), 2.0);
    expect(doubleOf(j, 'd'), 1.5);
  });

  test('dateOrNull parses ISO instants and calendar dates', () {
    final j = <String, dynamic>{'i': '2026-10-05T10:00:00.000Z', 'd': '2026-10-05', 'bad': 'x', 'e': ''};
    expect(dateOrNull(j, 'i')!.toUtc().hour, 10);
    expect(dateOrNull(j, 'd')!.day, 5);
    expect(dateOrNull(j, 'bad'), isNull);
    expect(dateOrNull(j, 'e'), isNull);
    expect(dateOrNull(j, 'missing'), isNull);
  });

  test('asMap, asList and stringList tolerate wrong types', () {
    expect(asMap(null), isEmpty);
    expect(asMap(<String, int>{'a': 1})['a'], 1);
    expect(asList('x'), isEmpty);
    expect(stringList(<dynamic>['a', 2]), <String>['a', '2']);
    expect(stringList(null), isEmpty);
  });
}
