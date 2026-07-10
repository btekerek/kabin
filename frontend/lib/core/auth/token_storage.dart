import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the refresh token in encrypted, platform-backed storage
/// (Android Keystore / iOS Keychain via flutter_secure_storage) rather
/// than shared_preferences, which is unencrypted and reserved for the
/// listener UUID (not a credential) - see ADR-001.
///
/// The access token is never persisted here; it lives only in memory
/// (AuthSession), re-issued on every refresh and lost on app kill, which
/// is fine since it's short-lived anyway.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshKey = 'kabin.refresh_token';

  final FlutterSecureStorage _storage;

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  Future<void> clear() => _storage.delete(key: _refreshKey);
}
