import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/device_token_registry_impl.dart';
import '../../domain/auth_repository.dart';
import '../../domain/push_registrar.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)),
);

final deviceTokenRegistryProvider = Provider<DeviceTokenRegistry>(
  (ref) => DeviceTokenRegistryImpl(ref.watch(apiClientProvider)),
);

/// Override with an FCM/APNs implementation when push is wired up.
final pushRegistrarProvider = Provider<PushRegistrar>((ref) => const NoopPushRegistrar());

/// Platform of the running app, for `POST /auth/devices`.
DevicePlatform currentDevicePlatform() {
  if (kIsWeb) return DevicePlatform.web;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return DevicePlatform.ios;
    case TargetPlatform.android:
      return DevicePlatform.android;
    default:
      return DevicePlatform.web;
  }
}
