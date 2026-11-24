import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/branch_map_picker_screen.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/test_harness.dart';

/// Draws a transparent pixel for every tile, so no test touches the network.
class _BlankTiles extends TileProvider {
  static final _png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

LatLng? _result;
bool _closed = false;

Future<void> _open(WidgetTester tester, {LatLng? initial}) async {
  _result = null;
  _closed = false;
  await pumpHvp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              _result = await BranchMapPickerScreen.open(context,
                  initial: initial, tileProvider: _BlankTiles());
              _closed = true;
            },
            child: const Text('mở'),
          ),
        ),
      ),
    ),
    overrides: const <Override>[],
  );
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nothing is picked until the map is tapped', (tester) async {
    await _open(tester);
    expect(
        find.text('Chạm vào bản đồ để ghim vị trí chi nhánh.'), findsOneWidget);
    expect(find.byType(RichAttributionWidget), findsOneWidget);

    // the confirm button is disabled: tapping it closes nothing
    await tester.tap(find.text('CHỌN VỊ TRÍ NÀY'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_closed, isFalse);
  });

  testWidgets('tap the map, then confirm returns that position',
      (tester) async {
    await _open(tester);
    await tester.tap(find.byType(FlutterMap));
    // flutter_map waits a moment to tell a tap from a double tap
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vĩ độ 10.7'), findsOneWidget);
    await tester.tap(find.text('CHỌN VỊ TRÍ NÀY'));
    await tester.pumpAndSettle();

    expect(_closed, isTrue);
    expect(_result, isNotNull);
    expect(_result!.latitude, closeTo(10.78, 0.05));
    expect(_result!.longitude, closeTo(106.70, 0.05));
  });

  testWidgets('opens with the saved position already pinned', (tester) async {
    await _open(tester, initial: const LatLng(10.5, 106.6));
    expect(find.text('Vĩ độ 10.500000 · Kinh độ 106.600000'), findsOneWidget);

    await tester.tap(find.text('CHỌN VỊ TRÍ NÀY'));
    await tester.pumpAndSettle();
    expect(_result, const LatLng(10.5, 106.6));
  });

  testWidgets('going back without confirming returns null', (tester) async {
    await _open(tester, initial: const LatLng(10.5, 106.6));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_closed, isTrue);
    expect(_result, isNull);
  });
}
