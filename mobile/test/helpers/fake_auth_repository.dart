import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/features/auth/domain/auth_repository.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';

/// In-memory [AuthRepository] for widget tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.restored, this.loginUser, this.loginError});

  /// Returned by [restoreSession]; null = signed out.
  AuthUser? restored;
  AuthUser? loginUser;
  ApiException? loginError;

  final List<String> loginIdentifiers = <String>[];
  final List<String> otpEmails = <String>[];
  final List<RegisterInput> registered = <RegisterInput>[];
  int logoutCalls = 0;

  @override
  Future<AuthUser> login({required String identifier, required String password}) async {
    loginIdentifiers.add(identifier);
    final error = loginError;
    if (error != null) throw error;
    return loginUser ?? makeUser(AppRole.student);
  }

  @override
  Future<AuthUser> register(RegisterInput input) async {
    registered.add(input);
    return loginUser ?? makeUser(AppRole.student);
  }

  @override
  Future<OtpTicket> requestRegisterOtp(String email) async {
    otpEmails.add(email);
    return const OtpTicket(requestId: 'otp-1', maskedDestination: 'ng***@gmail.com', devPin: '123456');
  }

  @override
  Future<AuthUser?> restoreSession() async => restored;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<OtpTicket> requestPasswordReset(String email) async =>
      const OtpTicket(requestId: 'req-1', maskedDestination: 'ng***@gmail.com');

  @override
  Future<String> verifyResetPin({required String requestId, required String pin}) async => 'reset-token';

  @override
  Future<void> resetPassword({
    required String requestId,
    required String resetToken,
    required String password,
    required String passwordConfirm,
  }) async {}
}

/// A user with the given app role and a neutral Vietnamese name.
AuthUser makeUser(AppRole role) => AuthUser(
      id: 'user-${role.name}',
      fullName: 'Người Dùng ${role.name}',
      appRole: role,
      phone: '0912345678',
    );
