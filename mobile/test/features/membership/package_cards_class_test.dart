import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/presentation/widgets/package_cards.dart';

import '../../helpers/test_harness.dart';

const _class = RenewalClass(
  id: 'c1',
  name: 'Boxing tối',
  branchName: 'HVP Quận 1',
  weekdays: <int>[1, 3, 5],
  startTime: '18:30',
);

void main() {
  testWidgets('waiting card and history tile show the chosen class',
      (tester) async {
    await pumpHvp(
      tester,
      Scaffold(
        body: Column(children: <Widget>[
          PendingRenewalCard(
              renewal: PendingRenewal(
                  packageName: 'BOOK II',
                  createdAt: DateTime.utc(2026, 10, 24),
                  classInfo: _class)),
          const RenewalRequestTile(
              request: RenewalRequest(
                  id: 'r1',
                  status: RenewalStatus.completed,
                  packageName: 'BOOK I',
                  createdAt: null,
                  classInfo: _class)),
          const RenewalRequestTile(
              request: RenewalRequest(
                  id: 'r2',
                  status: RenewalStatus.cancelled,
                  packageName: 'Tự do',
                  createdAt: null)),
        ]),
      ),
    );
    expect(find.text('Lớp: Boxing tối · HVP Quận 1 · T2, T4, T6 · 18:30'),
        findsNWidgets(2));
    expect(find.textContaining('Lớp:'), findsNWidgets(2));
  });
}
