import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';

void main() {
  tearDown(() => hvpEntranceEnabled = true);

  testWidgets('entrance animation reveals every staggered item', (tester) async {
    hvpEntranceEnabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              for (var i = 0; i < 12; i++) Text('item $i').entrance(i),
            ],
          ),
        ),
      ),
    );
    // Longest delay is capped at 8 steps * 60 ms; let all timers and tweens finish.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      expect(find.text('item $i'), findsOneWidget);
    }
  });

  testWidgets('disabled entrance returns the child untouched', (tester) async {
    hvpEntranceEnabled = false;
    const child = Text('plain');
    expect(identical(child.entrance(3), child), isTrue);
  });
}
