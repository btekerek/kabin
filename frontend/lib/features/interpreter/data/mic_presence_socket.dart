import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_config.dart';

/// One entry per remote interpreter currently known to be live/not-live
/// on this channel.
class MicStateEvent {
  const MicStateEvent({required this.userId, required this.live});

  final int userId;
  final bool live;
}

/// Relays "my mic is on/off" between interpreters sharing a channel (see
/// MicPresenceConsumer) - unlike ChatSocket this one does
/// send, not just receive: [sendMicState] pushes this client's own
/// mute/unmute, and every other interpreter connected to the same
/// channel gets it back through [events]. [requestStatus] asks the
/// group to resend current state, for catching up right after connect.
class MicPresenceSocket {
  WebSocketChannel? _channel;

  final _eventsController = StreamController<MicStateEvent>.broadcast();
  final _statusRequestsController = StreamController<void>.broadcast();
  final _sessionStatusController = StreamController<String>.broadcast();

  Stream<MicStateEvent> get events => _eventsController.stream;

  /// Fires whenever another client just connected and asked the group
  /// to catch it up - the screen should respond with its own current
  /// mic state via [sendMicState] if it's currently live.
  Stream<void> get statusRequests => _statusRequestsController.stream;

  /// Fires the instant the guide starts/stops/ends the session - pushed
  /// by _SessionTransitionView.after_transition, not sent by any client.
  Stream<String> get sessionStatusUpdates => _sessionStatusController.stream;

  void connect({required int channelId, required String accessToken}) {
    final wsBase = ApiConfig.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/ws/channels/$channelId/mic-presence/')
        .replace(queryParameters: {'token': accessToken});

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    channel.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        switch (json['type']) {
          case 'mic_state':
            _eventsController.add(MicStateEvent(
              userId: json['user_id'] as int,
              live: json['live'] as bool,
            ));
          case 'status_request':
            _statusRequestsController.add(null);
          case 'session_status':
            _sessionStatusController.add(json['status'] as String);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _eventsController.addError(error, stackTrace);
      },
    );

    requestStatus();
  }

  void sendMicState(bool live) {
    _channel?.sink.add(jsonEncode({'type': 'mic_state', 'live': live}));
  }

  void requestStatus() {
    _channel?.sink.add(jsonEncode({'type': 'status_request'}));
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    unawaited(disconnect());
    if (!_eventsController.isClosed) _eventsController.close();
    if (!_statusRequestsController.isClosed) _statusRequestsController.close();
    if (!_sessionStatusController.isClosed) _sessionStatusController.close();
  }
}
