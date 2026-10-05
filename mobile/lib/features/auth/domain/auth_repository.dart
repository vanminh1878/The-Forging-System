import 'auth_user.dart';

class RegisterInput {
  const RegisterInput({
    required this.fullName,
    required this.phone,
    required this.password,
    this.email,
    this.homeBranchId,
  });

  final String fullName;
  final String phone;
  final String password;
  final String? email;
  final String? homeBranchId;
}

/// Result of step 1 of the password reset (`/auth/password/forgot`).
class PasswordResetTicket {
  const PasswordResetTicket({required this.requestId, required this.maskedDestination, this.devPin});

  final String requestId;
  final String maskedDestination;

  /// Only returned by non-production backends with the console OTP provider.
  final String? devPin;
}

abstract class AuthRepository {
  /// [identifier] is an email or a phone number.
  Future<AuthUser> login({required String identifier, required String password});

  Future<AuthUser> register(RegisterInput input);

  /// Restores the stored session on cold start. Returns null when there is no
  /// valid session. Throws `ApiException` for network failures (session kept).
  Future<AuthUser?> restoreSession();

  /// Revokes the refresh token (best effort) and clears local credentials.
  Future<void> logout();

  Future<PasswordResetTicket> requestPasswordReset(String phone);

  /// Returns the short-lived reset token.
  Future<String> verifyResetPin({required String requestId, required String pin});

  Future<void> resetPassword({
    required String requestId,
    required String resetToken,
    required String password,
    required String passwordConfirm,
  });
}
