import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// API base URL, injected at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8000
class ApiConfig {
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      throw StateError(
        'API_BASE_URL is required on Android/iOS - a real device (or '
        "the emulator) can't reach the dev machine over loopback. Pass "
        '--dart-define=API_BASE_URL=http://<your-lan-ip>:8000, or set '
        'it up once via a PowerShell profile alias (see dev notes).',
      );
    }
    return 'http://127.0.0.1:8000';
  }
}
