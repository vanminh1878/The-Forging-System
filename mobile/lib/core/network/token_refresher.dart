import 'package:dio/dio.dart';

import '../error/error_mapper.dart';
import '../storage/token_store.dart';
import '../utils/json_utils.dart';

/// Exchanges a refresh token for a new pair. Throws `ApiException` on failure.
abstract class TokenRefresher {
  Future<StoredTokens> refresh(String refreshToken);
}

/// Uses a dedicated Dio (no auth interceptor) so a failing refresh can never recurse.
class DioTokenRefresher implements TokenRefresher {
  DioTokenRefresher(this._dio);

  final Dio _dio;

  @override
  Future<StoredTokens> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<dynamic>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
      final body = asMap(res.data);
      final data = asMap(body['data']);
      final access = str(data, 'accessToken');
      final refresh = str(data, 'refreshToken');
      if (access.isEmpty || refresh.isEmpty) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
        );
      }
      return StoredTokens(accessToken: access, refreshToken: refresh);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
