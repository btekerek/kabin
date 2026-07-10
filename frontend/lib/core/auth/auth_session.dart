import 'dart:async';

import 'token_pair.dart';
import 'token_storage.dart';

/// Holds the current access token in memory and delegates the refresh
/// token to [TokenStorage]. Also broadcasts "logged out" events so the
/// app shell can route to the login screen without the networking layer
/// (DioClientFactory) needing to know anything about navigation.
class AuthSession {
  AuthSession({TokenStorage? storage}) : _storage = storage ?? TokenStorage();

  final TokenStorage _storage;
  String? _accessToken;

  final _loggedOutController = StreamController<void>.broadcast();

  /// Fires when the refresh token itself turns out to be dead (expired or
  /// blacklisted) - a real logout, as opposed to a routine access-token
  /// refresh.
  Stream<void> get onLoggedOut => _loggedOutController.stream;

  String? get accessToken => _accessToken;

  Future<String?> get refreshToken => _storage.readRefreshToken();

  /// Called after login or a successful refresh.
  void updateTokens(TokenPair tokens) {
    _accessToken = tokens.access;
    unawaited(_storage.saveRefreshToken(tokens.refresh));
  }

  Future<void> clear() async {
    _accessToken = null;
    await _storage.clear();
  }

  /// Call when the refresh call itself fails. The refresh token is dead;
  /// there is no path back to a valid session short of logging in again.
  Future<void> forceLogout() async {
    await clear();
    _loggedOutController.add(null);
  }

  void dispose() {
    _loggedOutController.close();
  }
}
