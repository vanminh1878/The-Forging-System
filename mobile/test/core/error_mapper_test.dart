import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/error/error_mapper.dart';

DioException _bad(int status, Object? body) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  test('maps the backend error envelope', () {
    final e = mapDioException(_bad(422, <String, dynamic>{
      'error': <String, dynamic>{'code': 'TRIAL_NOT_AVAILABLE', 'message': 'Chưa đủ điều kiện.'},
    }));
    expect(e.code, 'TRIAL_NOT_AVAILABLE');
    expect(e.message, 'Chưa đủ điều kiện.');
    expect(e.statusCode, 422);
  });

  test('validation errors expose per-field messages', () {
    final e = mapDioException(_bad(400, <String, dynamic>{
      'error': <String, dynamic>{
        'code': 'VALIDATION_ERROR',
        'message': 'Invalid',
        'details': <dynamic>[
          <String, dynamic>{'path': 'phone', 'message': 'Số điện thoại không hợp lệ'},
        ],
      },
    }));
    expect(e.code, ApiErrorCodes.validation);
    expect(e.fieldErrors['phone'], 'Số điện thoại không hợp lệ');
    expect(e.message, contains('Số điện thoại không hợp lệ'));
  });

  test('non-envelope HTTP errors get a friendly Vietnamese message', () {
    expect(mapDioException(_bad(401, '')).code, ApiErrorCodes.unauthorized);
    expect(mapDioException(_bad(403, null)).message, contains('quyền'));
    expect(mapDioException(_bad(500, '<html>')).message, contains('Máy chủ'));
  });

  test('connection problems are network errors', () {
    final e = mapDioException(DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    ));
    expect(e.code, ApiErrorCodes.network);
    expect(e.isNetwork, isTrue);
  });

  test('timeouts are reported separately', () {
    final e = mapDioException(DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.receiveTimeout,
    ));
    expect(e.code, ApiErrorCodes.timeout);
  });

  test('errorMessage handles any object', () {
    expect(errorMessage(const ApiException(code: 'A', message: 'Xin chào')), 'Xin chào');
    expect(errorMessage(StateError('boom')), isNotEmpty);
    expect(errorMessage(null), isNotEmpty);
  });
}
