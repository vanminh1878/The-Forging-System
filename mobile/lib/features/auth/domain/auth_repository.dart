import 'auth_user.dart';

class RegisterInput {
  const RegisterInput({
    required this.fullName,
    required this.phone,
    required this.password,
    required this.email,
    required this.otpRequestId,
    required this.otp,
    this.homeBranchId,
  });

  final String fullName;
  final String phone;
  final String password;
  final String email;
  final String otpRequestId;
  final String otp;
  final String? homeBranchId;
}

/// Result of an OTP request (`/auth/register/otp`, `/auth/password/forgot`).
class OtpTicket {
  const OtpTicket({required this.requestId, required this.maskedDestination, this.devPin});

  final String requestId;
  final String maskedDestination;

  /// Only returned by non-production backends with the console OTP provider.
  final String? devPin;
}

abstract class AuthRepository {
  /// [identifier] is an email or a phone number.
  Future<AuthUser> login({required String identifier, required String password});

  Future<AuthUser> register(RegisterInput input);

  Future<OtpTicket> requestRegisterOtp(String email);

  /// Restores the stored session on cold start. Returns null when there is no
  /// valid session. Throws `ApiException` for network failures (session kept).
  Future<AuthUser?> restoreSession();

  /// Revokes the refresh token (best effort) and clears local credentials.
  Future<void> logout();

  Future<OtpTicket> requestPasswordReset(String email);

  /// Returns the short-lived reset token.
  Future<String> verifyResetPin({required String requestId, required String pin});

  Future<void> resetPassword({
    required String requestId,
    required String resetToken,
    required String password,
    required String passwordConfirm,
  });
}
