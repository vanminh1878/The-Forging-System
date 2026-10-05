import '../../../core/network/api_client.dart';
import '../domain/push_registrar.dart';

class DeviceTokenRegistryImpl implements DeviceTokenRegistry {
  DeviceTokenRegistryImpl(this._api);

  final ApiClient _api;

  @override
  Future<void> register({required String token, required DevicePlatform platform, String? provider}) async {
    await _api.post(
      '/auth/devices',
      body: <String, dynamic>{
        'token': token,
        'platform': platform.wire,
        if (provider != null) 'provider': provider,
      },
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _api.delete('/auth/devices', body: <String, dynamic>{'token': token});
  }
}
