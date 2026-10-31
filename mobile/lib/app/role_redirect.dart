import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import 'route_paths.dart';

/// Pure redirect rules of the router (unit tested).
///
/// * session unknown          -> splash
/// * signed out               -> login (register / forgot password stay reachable)
/// * signed in on a public page, `/` or a role root -> the role's home
/// * signed in on another role's area -> the role's home
///
/// Returns null when [location] may be shown as is.
String? redirectFor(AuthState auth, String location) {
  switch (auth.status) {
    case AuthStatus.unknown:
      return location == AppPaths.splash ? null : AppPaths.splash;
    case AuthStatus.signedOut:
      if (AppPaths.public.contains(location)) return null;
      return AppPaths.login;
    case AuthStatus.signedIn:
      if (auth.user?.mustChangePassword == true) {
        return location == AppPaths.changePassword
            ? null
            : AppPaths.changePassword;
      }
      if (location == AppPaths.changePassword) {
        return AppPaths.homeOf(auth.user?.appRole ?? AppRole.student);
      }
      final role = auth.user?.appRole ?? AppRole.student;
      final home = AppPaths.homeOf(role);
      final base = role.basePath;
      final inOwnArea = location == base || location.startsWith('$base/');
      if (location == base) return home;
      if (inOwnArea) return null;
      return home;
  }
}
