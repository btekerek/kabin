import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_config.dart';
import '../domain/message.dart';

/// Wraps the read-only chat WebSocket (see ChatConsumer/ADR-005 - it
/// only ever pushes messages created via the REST endpoint, never
/// accepts writes from the client). One instance is one session's
/// connection; a screen creates one on entry and disposes it on exit,
/// same lifecycle pattern as AgoraChannelController.
class ChatSocket {
  WebSocketChannel? _channel;
  final _messagesController = StreamController<ChatMessage>.broadcast();

  /// Emits every incoming chat message. Connection failures are
  /// forwarded as stream errors rather than swallowed, so a listener can
  /// show a "disconnected" state instead of silently missing messages.
  Stream<ChatMessage> get messages => _messagesController.stream;

  /// [queryParams] is `{'token': accessToken}` for guide/interpreter or
  /// `{'listener_uuid': uuid}` for a listener - see
  /// ChatConsumer._authorize for why auth travels in the URL rather than
  /// a header (neither browsers nor Flutter can attach custom headers to
  /// a WebSocket handshake).
  void connect({
    required int sessionId,
    required Map<String, String> queryParams,
  }) {
    // ApiConfig.baseUrl is http(s); the socket needs ws(s). Replacing
    // just the first "http" turns "https://" into "wss://" and
    // "http://" into "ws://" in one move.
    final wsBase = ApiConfig.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/ws/sessions/$sessionId/chat/')
        .replace(queryParameters: queryParams);

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    channel.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        _messagesController.add(ChatMessage.fromJson(json));
      },
      onError: (Object error, StackTrace stackTrace) =>
          _messagesController.addError(error, stackTrace),
    );
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    unawaited(disconnect());
    if (!_messagesController.isClosed) _messagesController.close();
  }
}
