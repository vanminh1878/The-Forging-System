import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<AuthUser> login({required String identifier, required String password}) async {
    final res = await _api.post(
      '/auth/login',
      auth: false,
      body: <String, dynamic>{'identifier': identifier.trim(), 'password': password},
    );
    return _storeSession(res.dataMap);
  }

  @override
  Future<AuthUser> register(RegisterInput input) async {
    final email = input.email?.trim() ?? '';
    final res = await _api.post(
      '/auth/register',
      auth: false,
      body: <String, dynamic>{
        'fullName': input.fullName.trim(),
        'phone': input.phone.trim(),
        'password': input.password,
        'passwordConfirm': input.password,
        if (email.isNotEmpty) 'email': email,
        if (input.homeBranchId != null) 'homeBranchId': input.homeBranchId,
      },
    );
    return _storeSession(res.dataMap);
  }

  Future<AuthUser> _storeSession(JsonMap data) async {
    final access = str(data, 'accessToken');
    final refresh = str(data, 'refreshToken');
    if (access.isEmpty || refresh.isEmpty) {
      throw const ApiException(code: ApiErrorCodes.unknown, message: 'Phản hồi đăng nhập không hợp lệ.');
    }
    await _tokens.save(StoredTokens(accessToken: access, refreshToken: refresh));
    return AuthUser.fromJson(asMap(data['user']));
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final stored = await _tokens.read();
    if (stored == null) return null;
    try {
      final res = await _api.get('/auth/me');
      return AuthUser.fromJson(res.dataMap);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final stored = await _tokens.read();
    try {
      if (stored != null) {
        await _api.post('/auth/logout', body: <String, dynamic>{'refreshToken': stored.refreshToken});
      }
    } catch (_) {
      // Best effort: the local session is cleared regardless.
    }
    await _tokens.clear();
  }

  @override
  Future<PasswordResetTicket> requestPasswordReset(String phone) async {
    final res = await _api.post('/auth/password/forgot', auth: false, body: <String, dynamic>{'phone': phone.trim()});
    final d = res.dataMap;
    return PasswordResetTicket(
      requestId: str(d, 'requestId'),
      maskedDestination: str(d, 'maskedDestination'),
      devPin: strOrNull(d, 'devPin'),
    );
  }

  @override
  Future<String> verifyResetPin({required String requestId, required String pin}) async {
    final res = await _api.post(
      '/auth/password/verify-pin',
      auth: false,
      body: <String, dynamic>{'requestId': requestId, 'pin': pin.trim()},
    );
    return str(res.dataMap, 'resetToken');
  }

  @override
  Future<void> resetPassword({
    required String requestId,
    required String resetToken,
    required String password,
    required String passwordConfirm,
  }) async {
    await _api.post(
      '/auth/password/reset',
      auth: false,
      body: <String, dynamic>{
        'requestId': requestId,
        'resetToken': resetToken,
        'password': password,
        'passwordConfirm': passwordConfirm,
      },
    );
  }
}
