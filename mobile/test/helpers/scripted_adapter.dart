import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Dio adapter that answers from a function, so no test touches the network.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;

  /// Every request received, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// JSON response with the given HTTP [status].
ResponseBody jsonResponse(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

/// Backend success envelope.
ResponseBody okEnvelope(Object? data, {Object? meta, int status = 200}) =>
    jsonResponse(status, <String, dynamic>{'data': data, if (meta != null) 'meta': meta});

/// Backend error envelope.
ResponseBody errorEnvelope(int status, String code, String message, {Object? details}) =>
    jsonResponse(status, <String, dynamic>{
      'error': <String, dynamic>{'code': code, 'message': message, if (details != null) 'details': details},
    });
