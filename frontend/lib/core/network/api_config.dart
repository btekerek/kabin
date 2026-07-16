/// API base URL, injected at build/run time:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
///
/// Defaults to the Android emulator's alias for the host machine's
/// localhost, since that's the common local-dev case.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
