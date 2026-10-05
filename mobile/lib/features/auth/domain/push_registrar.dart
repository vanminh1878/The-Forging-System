import 'auth_user.dart';

/// Hook for push notifications. The default is a no-op because no Firebase
/// package is bundled yet. A future FCM/APNs implementation obtains the device
/// token and calls `DeviceTokenRegistry.register(...)`.
abstract class PushRegistrar {
  Future<void> onSignedIn(AuthUser user);

  /// Called before the session is cleared so the token can be unregistered.
  Future<void> onSigningOut();
}

class NoopPushRegistrar implements PushRegistrar {
  const NoopPushRegistrar();

  @override
  Future<void> onSignedIn(AuthUser user) async {}

  @override
  Future<void> onSigningOut() async {}
}

enum DevicePlatform {
  android('ANDROID'),
  ios('IOS'),
  web('WEB');

  const DevicePlatform(this.wire);

  /// Value expected by `POST /auth/devices`.
  final String wire;
}

/// Wrapper of `POST/DELETE /auth/devices`.
abstract class DeviceTokenRegistry {
  Future<void> register({required String token, required DevicePlatform platform, String? provider});

  Future<void> unregister(String token);
}
