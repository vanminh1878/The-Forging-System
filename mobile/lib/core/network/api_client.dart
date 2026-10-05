import 'package:dio/dio.dart';

import '../error/error_mapper.dart';
import '../utils/json_utils.dart';
import 'interceptors.dart';

/// Parsed backend envelope `{ data, meta? }`.
class ApiEnvelope {
  const ApiEnvelope({this.data, this.meta});

  final Object? data;
  final JsonMap? meta;

  JsonMap get dataMap => asMap(data);
  List<dynamic> get dataList => asList(data);
}

/// Pagination block of list responses: `{ page, limit, total, totalPages }`.
class PageMeta {
  const PageMeta({required this.page, required this.limit, required this.total, required this.totalPages});

  factory PageMeta.fromJson(JsonMap? json, {int fallbackLimit = 20}) {
    final j = json ?? const <String, dynamic>{};
    return PageMeta(
      page: intOf(j, 'page', 1),
      limit: intOf(j, 'limit', fallbackLimit),
      total: intOf(j, 'total'),
      totalPages: intOf(j, 'totalPages', 1),
    );
  }

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Thin wrapper over Dio: unwraps the envelope and throws [ApiException] only.
class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  Future<ApiEnvelope> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: query, options: _options(auth)));

  Future<ApiEnvelope> post(String path, {Object? body, Map<String, dynamic>? query, bool auth = true}) =>
      _send(() => dio.post<dynamic>(path, data: body, queryParameters: query, options: _options(auth)));

  Future<ApiEnvelope> patch(String path, {Object? body, bool auth = true}) =>
      _send(() => dio.patch<dynamic>(path, data: body, options: _options(auth)));

  Future<ApiEnvelope> put(String path, {Object? body, bool auth = true}) =>
      _send(() => dio.put<dynamic>(path, data: body, options: _options(auth)));

  Future<ApiEnvelope> delete(String path, {Object? body, bool auth = true}) =>
      _send(() => dio.delete<dynamic>(path, data: body, options: _options(auth)));

  Options _options(bool auth) =>
      Options(extra: <String, dynamic>{if (!auth) skipAuthKey: true});

  Future<ApiEnvelope> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is Map) {
        final meta = body['meta'];
        return ApiEnvelope(data: body['data'], meta: meta is Map ? asMap(meta) : null);
      }
      return const ApiEnvelope();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
