import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'interceptors.dart';
import 'token_refresher.dart';

BaseOptions _baseOptions(AppConfig config) => BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
      headers: <String, dynamic>{'Accept': 'application/json'},
    );

/// Dio without the auth interceptor; used by the token refresher.
Dio createBareDio(AppConfig config) {
  final dio = Dio(_baseOptions(config));
  dio.interceptors.addAll(<Interceptor>[
    TenantInterceptor(config.tenantCode),
    ErrorMappingInterceptor(),
  ]);
  return dio;
}

/// The one Dio used by every repository.
Dio createApiDio({
  required AppConfig config,
  required TokenStore tokens,
  TokenRefresher? refresher,
  void Function()? onSessionExpired,
}) {
  final dio = Dio(_baseOptions(config));
  dio.interceptors.addAll(<Interceptor>[
    TenantInterceptor(config.tenantCode),
    AuthInterceptor(
      dio: dio,
      tokens: tokens,
      refresher: refresher ?? DioTokenRefresher(createBareDio(config)),
      onSessionExpired: onSessionExpired,
    ),
    ErrorMappingInterceptor(),
  ]);
  return dio;
}
