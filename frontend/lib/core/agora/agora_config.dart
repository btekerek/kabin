/// Agora App ID, injected at build/run time:
///   flutter run --dart-define=AGORA_APP_ID=<your app id>
///
/// This is the public App ID only - the App Certificate stays
/// server-side (see backend/apps/sessions/agora.py) and is never
/// shipped to the client. The engine needs the App ID to initialize;
/// the actual channel token (which encodes the certificate-signed
/// permission to join) comes from the backend per-join.
class AgoraConfig {
  static const String appId = String.fromEnvironment('AGORA_APP_ID');
}
