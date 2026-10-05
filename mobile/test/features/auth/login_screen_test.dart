import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/storage/storage_providers.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/core/widgets/inline_banner.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_providers.dart';
import 'package:hvp_forging/features/auth/presentation/screens/login_screen.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/test_harness.dart';

List<Override> _overrides(FakeAuthRepository repo) => <Override>[
      authRepositoryProvider.overrideWithValue(repo),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    ];

Finder get _loginButton => find.widgetWithText(HvpButton, 'ĐĂNG NHẬP');

void main() {
  testWidgets('empty form shows validation messages and does not call the API', (tester) async {
    final repo = FakeAuthRepository();
    await pumpHvp(tester, const LoginScreen(), overrides: _overrides(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_loginButton);
    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập email hoặc số điện thoại.'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
    expect(repo.loginIdentifiers, isEmpty);
  });

  testWidgets('valid credentials sign the user in with the role from the API', (tester) async {
    final repo = FakeAuthRepository(loginUser: makeUser(AppRole.coach));
    await pumpHvp(tester, const LoginScreen(), overrides: _overrides(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '0912345678');
    await tester.enterText(find.byType(TextFormField).at(1), 'abc123');
    await tester.ensureVisible(_loginButton);
    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    expect(repo.loginIdentifiers, <String>['0912345678']);
    final container = ProviderScope.containerOf(tester.element(find.byType(LoginScreen)));
    final auth = container.read(authControllerProvider);
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.user!.appRole, AppRole.coach);
  });

  testWidgets('a rejected login shows the server message in a banner', (tester) async {
    final repo = FakeAuthRepository(
      loginError: const ApiException(code: 'INVALID_CREDENTIALS', message: 'Sai thông tin đăng nhập', statusCode: 401),
    );
    await pumpHvp(tester, const LoginScreen(), overrides: _overrides(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.vn');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.ensureVisible(_loginButton);
    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    expect(find.byType(InlineBanner), findsOneWidget);
    expect(find.text('Sai thông tin đăng nhập'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(LoginScreen)));
    expect(container.read(authControllerProvider).isSignedIn, isFalse);
  });

  testWidgets('the password field can be revealed', (tester) async {
    await pumpHvp(tester, const LoginScreen(), overrides: _overrides(FakeAuthRepository()));
    await tester.pumpAndSettle();

    EditableText passwordField() => tester.widget<EditableText>(find.byType(EditableText).at(1));
    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });
}
