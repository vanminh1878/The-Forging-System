import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/app/role_redirect.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';

import '../helpers/fake_auth_repository.dart';

AuthState _in(AppRole role) => AuthState.signedIn(makeUser(role));

void main() {
  group('unknown session', () {
    const unknown = AuthState.unknown();

    test('everything goes to the splash screen', () {
      expect(redirectFor(unknown, '/student/home'), AppPaths.splash);
      expect(redirectFor(unknown, AppPaths.login), AppPaths.splash);
    });

    test('the splash screen itself is left alone', () {
      expect(redirectFor(unknown, AppPaths.splash), isNull);
    });
  });

  group('signed out', () {
    const out = AuthState.signedOut();

    test('public pages stay reachable', () {
      expect(redirectFor(out, AppPaths.login), isNull);
      expect(redirectFor(out, AppPaths.register), isNull);
      expect(redirectFor(out, AppPaths.forgotPassword), isNull);
    });

    test('protected pages and the splash go to login', () {
      expect(redirectFor(out, StudentPaths.home), AppPaths.login);
      expect(redirectFor(out, '/admin/dashboard'), AppPaths.login);
      expect(redirectFor(out, AppPaths.splash), AppPaths.login);
      expect(redirectFor(out, '/'), AppPaths.login);
    });
  });

  group('signed in', () {
    test('public pages and the splash redirect to the role home', () {
      expect(redirectFor(_in(AppRole.student), AppPaths.login), StudentPaths.home);
      expect(redirectFor(_in(AppRole.coach), AppPaths.splash), CoachPaths.today);
      expect(redirectFor(_in(AppRole.reception), AppPaths.register), ReceptionPaths.checkin);
      expect(redirectFor(_in(AppRole.admin), '/'), AdminPaths.dashboard);
    });

    test('the role root redirects to its first tab', () {
      expect(redirectFor(_in(AppRole.student), '/student'), StudentPaths.home);
      expect(redirectFor(_in(AppRole.admin), '/admin'), AdminPaths.dashboard);
    });

    test('own area is allowed, including pushed sub-screens', () {
      expect(redirectFor(_in(AppRole.student), StudentPaths.fighterRecord), isNull);
      expect(redirectFor(_in(AppRole.student), StudentPaths.lesson('42')), isNull);
      expect(redirectFor(_in(AppRole.coach), CoachPaths.rankTrial), isNull);
    });

    test('another role area is blocked', () {
      expect(redirectFor(_in(AppRole.student), '/admin/dashboard'), StudentPaths.home);
      expect(redirectFor(_in(AppRole.coach), StudentPaths.home), CoachPaths.today);
    });

    test('a path that merely starts with the role name is not its area', () {
      expect(redirectFor(_in(AppRole.student), '/studentship'), StudentPaths.home);
    });
  });

  test('every role has a home inside its own area', () {
    for (final role in AppRole.values) {
      expect(AppPaths.homeOf(role).startsWith('${role.basePath}/'), isTrue, reason: role.name);
    }
  });
}
