import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time configuration, injected with `--dart-define`.
///
/// Example: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1`
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.tenantCode,
    this.isDev = kDebugMode,
  });

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api/v1',
  );
  static const String _tenantCode = String.fromEnvironment(
    'TENANT_CODE',
    defaultValue: 'hvp',
  );

  factory AppConfig.fromEnvironment() =>
      const AppConfig(apiBaseUrl: _apiBaseUrl, tenantCode: _tenantCode);

  final String apiBaseUrl;
  final String tenantCode;

  /// Dev builds show helper UI such as the password-reset `devPin` banner.
  final bool isDev;
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
