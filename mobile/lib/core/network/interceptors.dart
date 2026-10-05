import 'dart:async';

import 'package:dio/dio.dart';

import '../error/api_exception.dart';
import '../error/error_mapper.dart';
import '../storage/token_store.dart';
import 'token_refresher.dart';

/// Marks a request that must not carry a bearer token nor trigger a refresh.
const String skipAuthKey = 'hvp_skip_auth';
const String _retriedKey = 'hvp_auth_retried';

/// Adds `X-Tenant-Code` to every request.
class TenantInterceptor extends Interceptor {
  TenantInterceptor(this.tenantCode);

  final String tenantCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Tenant-Code'] = tenantCode;
    handler.next(options);
  }
}

/// Bearer header + single-flight refresh on 401.
///
/// All requests that fail with 401 while a refresh is running wait for that one
/// refresh and are retried once with the new access token. The refresh token
/// rotates (single use), so two parallel refreshes would invalidate each other.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.tokens,
    required this.refresher,
    this.onSessionExpired,
  });

  /// The client that owns this interceptor; used to replay the failed request.
  final Dio dio;
  final TokenStore tokens;
  final TokenRefresher refresher;
  final void Function()? onSessionExpired;

  Future<StoredTokens?>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuthKey] == true) {
      handler.next(options);
      return;
    }
    final stored = await tokens.read();
    if (stored != null) {
      options.headers['Authorization'] = 'Bearer ${stored.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    if (!is401 || request.extra[skipAuthKey] == true || request.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }

    final sentHeader = request.headers['Authorization'];
    final fresh = await _refreshFor(sentHeader is String ? sentHeader : null);
    if (fresh == null) {
      handler.next(err);
      return;
    }

    try {
      final retry = request.copyWith(
        headers: <String, dynamic>{
          ...request.headers,
          'Authorization': 'Bearer ${fresh.accessToken}',
        },
        extra: <String, dynamic>{...request.extra, _retriedKey: true},
        data: request.data is FormData ? (request.data as FormData).clone() : request.data,
      );
      final response = await dio.fetch<dynamic>(retry);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<StoredTokens?> _refreshFor(String? sentHeader) {
    final running = _refreshing;
    if (running != null) return running;
    final future = _runRefresh(sentHeader).whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  Future<StoredTokens?> _runRefresh(String? sentHeader) async {
    final current = await tokens.read();
    if (current == null) return null;
    // Another request already rotated the tokens after this one was sent.
    if (sentHeader != null && sentHeader != 'Bearer ${current.accessToken}') {
      return current;
    }
    try {
      final next = await refresher.refresh(current.refreshToken);
      await tokens.save(next);
      return next;
    } on ApiException catch (e) {
      final rejected = e.statusCode == 400 || e.statusCode == 401 || e.statusCode == 403;
      if (rejected) {
        await tokens.clear();
        onSessionExpired?.call();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Last interceptor: rejects with a [DioException] whose `error` is an [ApiException].
class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is ApiException) {
      handler.next(err);
      return;
    }
    handler.next(err.copyWith(error: mapDioException(err)));
  }
}
