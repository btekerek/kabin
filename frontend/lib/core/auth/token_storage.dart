/// Holds the refresh token in memory only, for the life of this process -
/// deliberately never persisted to disk (not flutter_secure_storage, not
/// shared_preferences), matching this project's original design (see
/// the canli-ceviri reference implementation's ApiService, which keeps
/// its token in a plain in-memory field for the same reason).
///
/// This was previously backed by flutter_secure_storage, which on
/// Windows uses Windows Credential Manager keyed by a fixed target name
/// shared by every running copy of the app under one Windows account -
/// so two `flutter run -d windows` instances on the same dev machine
/// silently shared one login, and logging in as one role in one window
/// logged the other window in too. Going in-memory-only removes the
/// shared store entirely, so that can't happen, at the cost of the app
/// no longer remembering a login across a full restart - every fresh
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
