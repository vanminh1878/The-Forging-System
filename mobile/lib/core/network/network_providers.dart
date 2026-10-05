import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/storage_providers.dart';
import 'api_client.dart';
import 'dio_factory.dart';
import 'session_events.dart';

/// Single Dio instance for the whole app.
final dioProvider = Provider<Dio>((ref) {
  final dio = createApiDio(
    config: ref.watch(appConfigProvider),
    tokens: ref.watch(tokenStoreProvider),
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).expire(),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));
