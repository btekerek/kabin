import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'agora_channel_controller.dart' show AgoraConnectionStatus;
import 'mic_permission.dart';

class AgoraDualChannelController {
  RtcEngine? _engine;
  RtcConnection? _primaryConnection;
  RtcConnection? _secondaryConnection;

  AgoraConnectionStatus _primaryStatus = AgoraConnectionStatus.disconnected;
  AgoraConnectionStatus _secondaryStatus = AgoraConnectionStatus.disconnected;
  Timer? _statusPollTimer;

  final _primaryStatusController =
      StreamController<AgoraConnectionStatus>.broadcast();
  final _secondaryStatusController =
      StreamController<AgoraConnectionStatus>.broadcast();

  Stream<AgoraConnectionStatus> get primaryStatusStream =>
      _primaryStatusController.stream;
  Stream<AgoraConnectionStatus> get secondaryStatusStream =>
      _secondaryStatusController.stream;
  AgoraConnectionStatus get primaryStatus => _primaryStatus;
  AgoraConnectionStatus get secondaryStatus => _secondaryStatus;

  Future<void> join({
    required String appId,
    required String primaryChannelName,
    required String primaryToken,
    String? secondaryChannelName,
    String? secondaryToken,
  }) async {
    if (_engine != null) {
      await leave();
    }

    await requestMicrophonePermission();

    _setPrimaryStatus(AgoraConnectionStatus.connecting);
    if (secondaryChannelName != null) {
      _setSecondaryStatus(AgoraConnectionStatus.connecting);
    }

    final engine = createAgoraRtcEngine();
    _engine = engine;

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _setStatusForConnection(connection, AgoraConnectionStatus.connected);
        },
        onConnectionStateChanged: (connection, state, reason) {
          switch (state) {
            case ConnectionStateType.connectionStateConnected:
              _setStatusForConnection(
                  connection, AgoraConnectionStatus.connected);
              break;
            case ConnectionStateType.connectionStateReconnecting:
            case ConnectionStateType.connectionStateConnecting:
              _setStatusForConnection(
                  connection, AgoraConnectionStatus.connecting);
              break;
            case ConnectionStateType.connectionStateFailed:
              _setStatusForConnection(connection, AgoraConnectionStatus.failed);
              break;
            case ConnectionStateType.connectionStateDisconnected:
              _setStatusForConnection(
                  connection, AgoraConnectionStatus.disconnected);
              break;
          }
        },
        onError: (err, msg) {
          // Not connection-scoped in this callback - conservatively mark
          // both connections failed rather than guessing which broke.
          _setPrimaryStatus(AgoraConnectionStatus.failed);
          if (secondaryChannelName != null) {
            _setSecondaryStatus(AgoraConnectionStatus.failed);
          }
        },
      ),
    );

    await engine.initialize(RtcEngineContext(appId: appId));
    await engine.enableAudio();

    // The multi-channel methods (joinChannelEx, leaveChannelEx,
    // getConnectionStateEx, muteLocalAudioStreamEx) live on a separate
    // RtcEngineEx interface, not on RtcEngine itself - the concrete
    // engine object implements both, but reaching those methods needs
    // an explicit cast.
    final engineEx = engine as RtcEngineEx;

    // joinChannelEx (unlike plain joinChannel) rejects the wildcard uid 0
    // with ERR_INVALID_USER_ID (-121) - it needs an explicit non-zero uid
    // per connection. The backend's tokens are wildcard (uid 0 at
    // generation time), which is exactly what lets the client pick any
    // real uid here and still validate. Now that more than one
    // interpreter can join the same target channel (see ADR-008), that
    // uid has to be random rather than a fixed constant - two clients on
    // the same channel with the same uid conflict.
    final primaryConnection = RtcConnection(
        channelId: primaryChannelName, localUid: _randomLocalUid());
    _primaryConnection = primaryConnection;

    await engineEx.joinChannelEx(
      token: primaryToken,
      connection: primaryConnection,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: false,
      ),
    );
    // Joining publishes the mic track immediately - mute right away so
    // an interpreter always starts silent and has to opt in to going
    // live, rather than broadcasting the instant they connect.
    await engineEx.muteLocalAudioStreamEx(
        mute: true, connection: primaryConnection);

    if (secondaryChannelName != null && secondaryToken != null) {
      try {
        final secondaryConnection = RtcConnection(
            channelId: secondaryChannelName, localUid: _randomLocalUid());
        _secondaryConnection = secondaryConnection;
        await engineEx.joinChannelEx(
          token: secondaryToken,
          connection: secondaryConnection,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleAudience,
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            publishMicrophoneTrack: false,
            autoSubscribeAudio: true,
          ),
        );
      } catch (_) {
        _setSecondaryStatus(AgoraConnectionStatus.failed);
      }
    }

    _startConnectionStatePolling(engine);
  }

  /// Same rationale as AgoraChannelController's poll: the native SDK's
  /// join can succeed while the Dart event bridge never delivers the
  /// callback, so ground truth is queried directly rather than trusting
  /// only events.
  void _startConnectionStatePolling(RtcEngine engine) {
    _statusPollTimer?.cancel();
    var elapsed = Duration.zero;
    const interval = Duration(milliseconds: 500);
    const giveUpAfter = Duration(seconds: 20);

    _statusPollTimer = Timer.periodic(interval, (timer) async {
      final primaryDone = _primaryStatus == AgoraConnectionStatus.connected ||
          _primaryStatus == AgoraConnectionStatus.failed;
      final secondaryDone = _secondaryConnection == null ||
          _secondaryStatus == AgoraConnectionStatus.connected ||
          _secondaryStatus == AgoraConnectionStatus.failed;
      if (primaryDone && secondaryDone) {
        timer.cancel();
        return;
      }

      elapsed += interval;
      final engineEx = engine as RtcEngineEx;
      if (!primaryDone) {
        final state = await engineEx.getConnectionStateEx(_primaryConnection!);
        _applyPolledState(_setPrimaryStatus, state, elapsed, giveUpAfter);
      }
      if (!secondaryDone && _secondaryConnection != null) {
        final state =
            await engineEx.getConnectionStateEx(_secondaryConnection!);
        _applyPolledState(_setSecondaryStatus, state, elapsed, giveUpAfter);
      }
      if (elapsed >= giveUpAfter) {
        timer.cancel();
      }
    });
  }

  void _applyPolledState(
    void Function(AgoraConnectionStatus) setStatus,
    ConnectionStateType state,
    Duration elapsed,
    Duration giveUpAfter,
  ) {
    if (state == ConnectionStateType.connectionStateConnected) {
      setStatus(AgoraConnectionStatus.connected);
    } else if (state == ConnectionStateType.connectionStateFailed ||
        elapsed >= giveUpAfter) {
      setStatus(AgoraConnectionStatus.failed);
    }
  }

  /// Leaves the current secondary (relay) connection, if any, and joins
  /// a new one - the primary/broadcast connection is untouched, so this
  /// lets an interpreter switch which channel they're relaying from
  /// without dropping their own live mic.
  Future<void> switchSecondary({
    required String channelName,
    required String token,
  }) async {
    final engine = _engine;
    if (engine == null) return;
    final engineEx = engine as RtcEngineEx;

    final oldSecondary = _secondaryConnection;
    _secondaryConnection = null;
    if (oldSecondary != null) {
      await engineEx.leaveChannelEx(connection: oldSecondary);
    }

    _setSecondaryStatus(AgoraConnectionStatus.connecting);
    try {
      final secondaryConnection =
          RtcConnection(channelId: channelName, localUid: _randomLocalUid());
      _secondaryConnection = secondaryConnection;
      await engineEx.joinChannelEx(
        token: token,
        connection: secondaryConnection,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
        ),
      );
      _startConnectionStatePolling(engine);
    } catch (_) {
      _setSecondaryStatus(AgoraConnectionStatus.failed);
    }
  }

  /// Mutes/unmutes the interpreter's own mic (the primary/broadcast
  /// connection) - there's nothing to mute on the audience-only
  /// secondary connection.
  Future<void> setMicMuted(bool muted) async {
    final engine = _engine;
    final connection = _primaryConnection;
    if (engine == null || connection == null) return;
    await (engine as RtcEngineEx)
        .muteLocalAudioStreamEx(mute: muted, connection: connection);
  }

  Future<void> leave() async {
    _statusPollTimer?.cancel();
    final engine = _engine;
    if (engine == null) return;
    _engine = null;
    final engineEx = engine as RtcEngineEx;
    final primary = _primaryConnection;
    final secondary = _secondaryConnection;
    _primaryConnection = null;
    _secondaryConnection = null;
    if (primary != null) await engineEx.leaveChannelEx(connection: primary);
    if (secondary != null) await engineEx.leaveChannelEx(connection: secondary);
    await engine.release();
    _setPrimaryStatus(AgoraConnectionStatus.disconnected);
    _setSecondaryStatus(AgoraConnectionStatus.disconnected);
  }

  void dispose() {
    _statusPollTimer?.cancel();
    unawaited(leave());
    _primaryStatusController.close();
    _secondaryStatusController.close();
  }

  void _setStatusForConnection(
      RtcConnection connection, AgoraConnectionStatus status) {
    if (connection.channelId == _primaryConnection?.channelId) {
      _setPrimaryStatus(status);
    } else if (connection.channelId == _secondaryConnection?.channelId) {
      _setSecondaryStatus(status);
    }
  }

  void _setPrimaryStatus(AgoraConnectionStatus status) {
    _primaryStatus = status;
    _primaryStatusController.add(status);
  }

  void _setSecondaryStatus(AgoraConnectionStatus status) {
    _secondaryStatus = status;
    _secondaryStatusController.add(status);
  }

  int _randomLocalUid() => Random().nextInt(0x7ffffffe) + 1;
}
