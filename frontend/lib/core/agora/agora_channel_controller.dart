import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shared connection lifecycle for both roles that touch live audio -
/// Interpreter (publishes into a channel) and Listener (subscribes to
/// one). One controller instance is one channel connection; a screen
/// creates one on entry and disposes it on exit rather than sharing a
/// single long-lived engine across screens, since only one channel is
/// ever joined at a time per role in this app.
enum AgoraConnectionStatus { disconnected, connecting, connected, failed }

class AgoraChannelController {
  RtcEngine? _engine;
  AgoraConnectionStatus _status = AgoraConnectionStatus.disconnected;
  Timer? _statusPollTimer;

  final _statusController = StreamController<AgoraConnectionStatus>.broadcast();

  Stream<AgoraConnectionStatus> get statusStream => _statusController.stream;
  AgoraConnectionStatus get status => _status;

  /// Joins [channelName] using a token issued by the backend (see
  /// ADR-002/ADR-003 for how listener vs. interpreter tokens differ).
  /// [asBroadcaster] controls both the Agora client role (publisher vs.
  /// audience) and whether microphone permission is requested at all -
  /// a Listener never needs mic access.
  Future<void> join({
    required String appId,
    required String channelName,
    required String token,
    required bool asBroadcaster,
  }) async {
    if (asBroadcaster) {
      await _requestMicrophonePermission();
    }

    _setStatus(AgoraConnectionStatus.connecting);

    final engine = createAgoraRtcEngine();
    _engine = engine;

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _setStatus(AgoraConnectionStatus.connected);
        },
        onConnectionStateChanged: (connection, state, reason) {
          switch (state) {
            case ConnectionStateType.connectionStateConnected:
              _setStatus(AgoraConnectionStatus.connected);
              break;
            case ConnectionStateType.connectionStateReconnecting:
            case ConnectionStateType.connectionStateConnecting:
              _setStatus(AgoraConnectionStatus.connecting);
              break;
            case ConnectionStateType.connectionStateFailed:
              _setStatus(AgoraConnectionStatus.failed);
              break;
            case ConnectionStateType.connectionStateDisconnected:
              _setStatus(AgoraConnectionStatus.disconnected);
              break;
          }
        },
        onError: (err, msg) {
          _setStatus(AgoraConnectionStatus.failed);
        },
      ),
    );

    await engine.initialize(RtcEngineContext(appId: appId));
    await engine.enableAudio();

    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: ChannelMediaOptions(
        clientRoleType: asBroadcaster
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    _startConnectionStatePolling(engine);
  }

  /// Fallback for an observed Windows-plugin gap: the native SDK's own
  /// log can show a fully successful join (onJoinChannelSuccess firing
  /// natively, elapsed ~300ms) while neither onJoinChannelSuccess nor
  /// onConnectionStateChanged ever reaches this Dart event handler,
  /// leaving the UI stuck on "connecting" forever despite the engine
  /// actually being connected. RtcEngine.getConnectionState() is ground
  /// truth queried directly, independent of whether that event bridge
  /// delivers - so polling it catches a connect the callback missed.
  /// Also caps the wait: if genuinely still not connected after 20s,
  /// report failed instead of hanging indefinitely with no feedback.
  void _startConnectionStatePolling(RtcEngine engine) {
    _statusPollTimer?.cancel();
    var elapsed = Duration.zero;
    const interval = Duration(milliseconds: 500);
    const giveUpAfter = Duration(seconds: 20);

    _statusPollTimer = Timer.periodic(interval, (timer) async {
      if (_status == AgoraConnectionStatus.connected ||
          _status == AgoraConnectionStatus.failed) {
        timer.cancel();
        return;
      }

      elapsed += interval;
      final state = await engine.getConnectionState();
      if (state == ConnectionStateType.connectionStateConnected) {
        _setStatus(AgoraConnectionStatus.connected);
        timer.cancel();
      } else if (state == ConnectionStateType.connectionStateFailed ||
          elapsed >= giveUpAfter) {
        _setStatus(AgoraConnectionStatus.failed);
        timer.cancel();
      }
    });
  }

  /// Interpreter-only: mute/unmute the local mic without leaving the
  /// channel. No-op if this controller was joined as a Listener (there's
  /// nothing local to mute).
  Future<void> setMicMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> leave() async {
    _statusPollTimer?.cancel();
    final engine = _engine;
    if (engine == null) return;
    _engine = null;
    await engine.leaveChannel();
    await engine.release();
    _setStatus(AgoraConnectionStatus.disconnected);
  }

  void dispose() {
    _statusPollTimer?.cancel();
    unawaited(leave());
    _statusController.close();
  }

  /// permission_handler's platform support varies (notably: limited on
  /// Windows/Linux desktop). Treated as best-effort - if the platform
  /// can't report a permission status at all, proceed and let Agora's
  /// own mic-open call surface any real failure, rather than blocking
  /// every desktop platform on a permission API that may not exist there.
  Future<void> _requestMicrophonePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return;
    }
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw StateError('Microphone permission was not granted.');
    }
  }

  void _setStatus(AgoraConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
