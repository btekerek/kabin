import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// API base URL, injected at build/run time:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
///
/// Without an override, picks a sane default for local dev per platform:
/// the Android emulator can't reach the host machine's loopback address
/// directly, so it needs 10.0.2.2 (the emulator's alias for the host);
/// every other platform (Windows/macOS/Linux desktop, iOS simulator,
/// web) can reach the host's own loopback directly, so those use it.
/// 127.0.0.1 specifically, not "localhost" - on Windows "localhost" can
/// resolve to the IPv6 loopback (::1) first, and if that hangs instead
/// of failing fast, every request silently stalls for the OS's full TCP
/// connect timeout with no server-side trace at all, since the packets
/// never reach a server bound to the IPv4 address.
class ApiConfig {
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }
}
