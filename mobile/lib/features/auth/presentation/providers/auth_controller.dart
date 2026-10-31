import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/network/session_events.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';
import 'auth_providers.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Session state observed by the router and by every user-scoped provider.
class AuthState {
  const AuthState.unknown({this.restoreError})
      : status = AuthStatus.unknown,
        user = null,
        notice = null;

  const AuthState.signedOut({this.notice})
      : status = AuthStatus.signedOut,
        user = null,
        restoreError = null;

  const AuthState.signedIn(AuthUser signedInUser)
      : status = AuthStatus.signedIn,
        user = signedInUser,
        notice = null,
        restoreError = null;

  final AuthStatus status;
  final AuthUser? user;

  /// Message shown on the login screen (e.g. session expired).
  final String? notice;

  /// Set when the cold-start restore failed because of the network.
  final String? restoreError;

  bool get isSignedIn => status == AuthStatus.signedIn;
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.listen<int>(sessionExpiredProvider, (previous, next) {
      if (previous != next && state.isSignedIn) {
        state = const AuthState.signedOut(
            notice: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }
    });
    Future<void>.microtask(restore);
    return const AuthState.unknown();
  }

  /// Cold-start session restore.
  Future<void> restore() async {
    state = const AuthState.unknown();
    try {
      final user = await _repo.restoreSession();
      if (user == null) {
        state = const AuthState.signedOut();
      } else {
        _enter(user);
      }
    } catch (e) {
      state = AuthState.unknown(restoreError: errorMessage(e));
    }
  }

  /// Throws `ApiException` on failure so forms can show the message.
  Future<void> login(
      {required String identifier, required String password}) async {
    final user = await _repo.login(identifier: identifier, password: password);
    _enter(user);
  }

  Future<void> register(RegisterInput input) async {
    final user = await _repo.register(input);
    _enter(user);
  }

  Future<void> logout() async {
    try {
      await ref.read(pushRegistrarProvider).onSigningOut();
    } catch (_) {
      // Push is best effort.
    }
    await _repo.logout();
    state = const AuthState.signedOut();
  }

  Future<void> changeTemporaryPassword(
      {required String currentPassword,
      required String password,
      required String passwordConfirm}) async {
    await _repo.changePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirm: passwordConfirm);
    await _repo.logout();
    state = const AuthState.signedOut(
        notice: 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
  }

  /// Keeps the cached name/avatar in sync after a profile edit.
  void updateUser(AuthUser Function(AuthUser current) change) {
    final current = state.user;
    if (current == null) return;
    state = AuthState.signedIn(change(current));
  }

  void _enter(AuthUser user) {
    state = AuthState.signedIn(user);
    final registrar = ref.read(pushRegistrarProvider);
    unawaited(registrar.onSignedIn(user).catchError((Object _) {}));
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider =
    Provider<AuthUser?>((ref) => ref.watch(authControllerProvider).user);

/// Watch this from user-scoped providers so they rebuild on sign-in/sign-out.
final currentUserIdProvider = Provider<String?>(
    (ref) => ref.watch(authControllerProvider.select((s) => s.user?.id)));

final appRoleProvider = Provider<AppRole?>(
    (ref) => ref.watch(authControllerProvider.select((s) => s.user?.appRole)));
