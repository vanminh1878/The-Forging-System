/// Stable machine-readable error codes used by the client itself.
abstract final class ApiErrorCodes {
  static const String network = 'NETWORK_ERROR';
  static const String timeout = 'TIMEOUT';
  static const String unknown = 'UNKNOWN';
  static const String validation = 'VALIDATION_ERROR';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String refreshInvalid = 'REFRESH_INVALID';
  static const String cancelled = 'CANCELLED';
}

/// Typed error raised by the networking layer. UI code switches on [code].
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;

  /// Message that is safe to show to the user (Vietnamese).
  final String message;
  final int? statusCode;
  final Object? details;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => code == ApiErrorCodes.network || code == ApiErrorCodes.timeout;

  /// Field level validation errors (`details: [{path, message}]`) keyed by path.
  Map<String, String> get fieldErrors {
    final d = details;
    final out = <String, String>{};
    if (d is List) {
      for (final item in d) {
        if (item is Map) {
          final path = item['path'];
          final msg = item['message'];
          if (path is String && msg is String && path.isNotEmpty) {
            out.putIfAbsent(path, () => msg);
          }
        }
      }
    }
    return out;
  }

  @override
  String toString() => 'ApiException($code, $statusCode, $message)';
}
