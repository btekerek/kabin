import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'mic_permission.dart';

enum AgoraConnectionStatus { disconnected, connecting, connected, failed }

class AgoraChannelController {
  RtcEngine? _engine;
  AgoraConnectionStatus _status = AgoraConnectionStatus.disconnected;
  Timer? _statusPollTimer;

  final _statusController = StreamController<AgoraConnectionStatus>.broadcast();

  Stream<AgoraConnectionStatus> get statusStream => _statusController.stream;
  AgoraConnectionStatus get status => _status;

  Future<void> join({
    required String appId,
    required String channelName,
    required String token,
    required bool asBroadcaster,
  }) async {
    if (_engine != null) {
      await leave();
    }

    if (asBroadcaster) {
      await requestMicrophonePermission();
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
    if (!asBroadcaster) {
      await engine.enableLocalAudio(false);
    }

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
    if (asBroadcaster) {
      // Joining publishes the mic track immediately - mute right away so
      // the Guide always starts silent and has to opt in to going live.
      await engine.muteLocalAudioStream(true);
    }

    _startConnectionStatePolling(engine);
  }

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

  /// Broadcaster-only: mute/unmute the local mic without leaving the
  /// channel. No-op if this controller was joined as audience (there's
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

  void _setStatus(AgoraConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
