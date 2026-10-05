import 'package:dio/dio.dart';

import 'api_exception.dart';

const String _msgNetwork = 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
const String _msgTimeout = 'Máy chủ phản hồi quá chậm. Vui lòng thử lại.';
const String _msgUnknown = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
const String _msgValidation = 'Dữ liệu chưa hợp lệ. Vui lòng kiểm tra lại các trường đã nhập.';
const String _msgServer = 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';

/// Converts any [DioException] into the typed [ApiException].
///
/// Backend error envelope: `{ "error": { "code", "message", "details"? } }`.
ApiException mapDioException(DioException e) {
  final inner = e.error;
  if (inner is ApiException) return inner;

  final response = e.response;
  final status = response?.statusCode;
  final body = response?.data;

  if (body is Map && body['error'] is Map) {
    final err = body['error'] as Map;
    final code = err['code'] is String ? err['code'] as String : ApiErrorCodes.unknown;
    final rawMessage = err['message'] is String ? err['message'] as String : '';
    final message = code == ApiErrorCodes.validation
        ? _validationMessage(err['details'])
        : (rawMessage.isNotEmpty ? rawMessage : _fallbackForStatus(status));
    return ApiException(
      code: code,
      message: message,
      statusCode: status,
      details: err['details'],
    );
  }

  if (status != null) {
    return ApiException(
      code: status == 401 ? ApiErrorCodes.unauthorized : ApiErrorCodes.unknown,
      message: _fallbackForStatus(status),
      statusCode: status,
    );
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const ApiException(code: ApiErrorCodes.timeout, message: _msgTimeout);
    case DioExceptionType.cancel:
      return const ApiException(code: ApiErrorCodes.cancelled, message: 'Đã huỷ yêu cầu.');
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
    case DioExceptionType.badResponse:
      return const ApiException(code: ApiErrorCodes.network, message: _msgNetwork);
  }
}

String _validationMessage(Object? details) {
  if (details is List && details.isNotEmpty && details.first is Map) {
    final first = details.first as Map;
    final msg = first['message'];
    if (msg is String && msg.isNotEmpty) return '$_msgValidation ($msg)';
  }
  return _msgValidation;
}

String _fallbackForStatus(int? status) {
  if (status == null) return _msgUnknown;
  if (status == 401) return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  if (status == 403) return 'Bạn không có quyền thực hiện thao tác này.';
  if (status == 404) return 'Không tìm thấy dữ liệu yêu cầu.';
  if (status >= 500) return _msgServer;
  return _msgUnknown;
}

/// Maps any thrown object to a user-facing Vietnamese message.
String errorMessage(Object? error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return mapDioException(error).message;
  return _msgUnknown;
}
