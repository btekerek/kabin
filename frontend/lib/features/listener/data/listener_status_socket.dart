import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_config.dart';

/// Read-only: relays the session's status ("not_started"/"active"/
/// "ended") to a listener currently on one channel - see
/// ListenerStatusConsumer. Lets ListeningScreen show a clear "this
/// session has ended" banner instead of the audio just going silent
/// with no explanation.
class ListenerStatusSocket {
  WebSocketChannel? _channel;

  final _statusController = StreamController<String>.broadcast();

  Stream<String> get statusUpdates => _statusController.stream;

  void connect({required int channelId, required String listenerUuid}) {
    final wsBase = ApiConfig.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/ws/channels/$channelId/listener-status/')
        .replace(queryParameters: {'listener_uuid': listenerUuid});

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    channel.stream.listen((data) {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      if (json['type'] == 'session_status') {
        _statusController.add(json['status'] as String);
      }
    });
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    unawaited(disconnect());
    if (!_statusController.isClosed) _statusController.close();
  }
}
