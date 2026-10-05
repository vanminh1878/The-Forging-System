import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access + rotating refresh token pair.
class StoredTokens {
  const StoredTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Persistence for the session tokens. Implementations must never log values.
abstract class TokenStore {
  Future<StoredTokens?> read();
  Future<void> save(StoredTokens tokens);
  Future<void> clear();
}

/// Keychain / Keystore / WebCrypto backed store with an in-memory cache.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _accessKey = 'hvp_access_token';
  static const String _refreshKey = 'hvp_refresh_token';

  final FlutterSecureStorage _storage;
  StoredTokens? _cache;
  bool _loaded = false;

  @override
  Future<StoredTokens?> read() async {
    if (_loaded) return _cache;
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      if (access != null && refresh != null) {
        _cache = StoredTokens(accessToken: access, refreshToken: refresh);
      }
    } catch (_) {
      _cache = null;
    }
    _loaded = true;
    return _cache;
  }

  @override
  Future<void> save(StoredTokens tokens) async {
    _cache = tokens;
    _loaded = true;
    try {
      await _storage.write(key: _accessKey, value: tokens.accessToken);
      await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    } catch (_) {
      // Keep the in-memory copy: the session still works until the app restarts.
    }
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // Nothing else to do.
    }
  }
}

/// Volatile store used by tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._tokens]);

  StoredTokens? _tokens;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> save(StoredTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
