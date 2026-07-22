/// Holds the refresh token in memory only, never persisted to disk.
/// The app doesn't remember a login across a full restart; every fresh
/// launch starts at the login screen.
class TokenStorage {
  String? _refreshToken;

  Future<String?> readRefreshToken() async => _refreshToken;

  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
  }

  Future<void> clear() async {
    _refreshToken = null;
  }
}
