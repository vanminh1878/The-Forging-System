import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/storage/storage_providers.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_providers.dart';
import 'package:hvp_forging/features/auth/presentation/screens/register_screen.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/test_harness.dart';

void main() {
  testWidgets('register requests an OTP first, then submits it with the form', (tester) async {
    final repo = FakeAuthRepository();
    await pumpHvp(
      tester,
      const RegisterScreen(),
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      ],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn An');
    await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
    await tester.enterText(find.byType(TextFormField).at(2), 'an@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'abc123');
    await tester.enterText(find.byType(TextFormField).at(4), 'abc123');
    final first = find.widgetWithText(HvpButton, 'ĐĂNG KÝ');
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();

    expect(repo.otpEmails, <String>['an@gmail.com']);
    expect(repo.registered, isEmpty);
    expect(find.text('Mã xác thực đã gửi tới ng***@gmail.com'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(5), '123456');
    final confirm = find.widgetWithText(HvpButton, 'XÁC NHẬN & ĐĂNG KÝ');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(repo.registered, hasLength(1));
    expect(repo.registered.single.otpRequestId, 'otp-1');
    expect(repo.registered.single.otp, '123456');
    expect(repo.registered.single.email, 'an@gmail.com');
  });
}
