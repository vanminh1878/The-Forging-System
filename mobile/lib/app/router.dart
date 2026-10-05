import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import 'role_redirect.dart';
import 'route_paths.dart';
import 'routes/admin_routes.dart';
import 'routes/coach_routes.dart';
import 'routes/reception_routes.dart';
import 'routes/student_routes.dart';

/// The app router. Composition only: screens of each role are registered in
/// `lib/app/routes/<role>_routes.dart`, redirects live in `role_redirect.dart`.
final routerProvider = Provider<GoRouter>((ref) {
  // Tells go_router to re-run `redirect` whenever the session changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (previous, next) => refresh.value++);

  final router = GoRouter(
    initialLocation: AppPaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(ref.read(authControllerProvider), state.uri.path),
    routes: <RouteBase>[
      GoRoute(path: AppPaths.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppPaths.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppPaths.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: AppPaths.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
      ...studentRoutes(),
      ...coachRoutes(),
      ...receptionRoutes(),
      ...adminRoutes(),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
