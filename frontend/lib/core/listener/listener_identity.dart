import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// The anonymous Listener's sole "credential" - a client-generated UUID
/// with no Django account behind it. Persisted in
/// shared_preferences rather than flutter_secure_storage: it's not a
/// secret, just a stable identity so rejoining or switching channels
/// reuses the same ListenerSession row instead of spending a second
/// seat against the session's listener cap.
class ListenerIdentity {
  static const _key = 'kabin.listener_uuid';

  Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null) return existing;

    final generated = const Uuid().v4();
    await prefs.setString(_key, generated);
    return generated;
  }
}
