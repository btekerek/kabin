import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_config.dart';
import '../domain/message.dart';

/// Mirrors AgoraConnectionStatus's shape (see core/agora) for the same
/// reason: a screen needs to show "reconnecting" without losing the
/// message history it already has, rather than an all-or-nothing
/// loading/error state.
enum ChatConnectionStatus { connecting, connected, disconnected }

/// Wraps the read-only chat WebSocket (see ChatConsumer/ADR-005 - it
/// only ever pushes messages created via the REST endpoint, never
/// accepts writes from the client). One instance is one session's
/// connection; a screen creates one on entry and disposes it on exit,
/// same lifecycle pattern as AgoraChannelController.
class ChatSocket {
  WebSocketChannel? _channel;
  ChatConnectionStatus _status = ChatConnectionStatus.disconnected;

  final _messagesController = StreamController<ChatMessage>.broadcast();
  final _statusController = StreamController<ChatConnectionStatus>.broadcast();

  /// Emits every incoming chat message. Connection failures are
  /// forwarded as stream errors rather than swallowed, so a listener can
  /// show a "disconnected" state instead of silently missing messages.
  Stream<ChatMessage> get messages => _messagesController.stream;

  Stream<ChatConnectionStatus> get statusStream => _statusController.stream;
  ChatConnectionStatus get status => _status;

  /// [queryParams] is `{'token': accessToken}` for guide/interpreter or
  /// `{'listener_uuid': uuid}` for a listener - see
  /// ChatConsumer._authorize for why auth travels in the URL rather than
  /// a header (neither browsers nor Flutter can attach custom headers to
  /// a WebSocket handshake).
  void connect({
    required int sessionId,
    required Map<String, String> queryParams,
  }) {
    _setStatus(ChatConnectionStatus.connecting);

    // ApiConfig.baseUrl is http(s); the socket needs ws(s). Replacing
    // just the first "http" turns "https://" into "wss://" and
    // "http://" into "ws://" in one move.
    final wsBase = ApiConfig.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/ws/sessions/$sessionId/chat/')
        .replace(queryParameters: queryParams);

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    // WebSocketChannel.connect() doesn't guarantee the handshake
    // succeeded yet - a rejected connection (e.g. NOT_A_PARTICIPANT,
    // see ChatConsumer._authorize) surfaces as a stream error/onDone
    // shortly after, which flips status to disconnected below.
    _setStatus(ChatConnectionStatus.connected);

    channel.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        _messagesController.add(ChatMessage.fromJson(json));
      },
      onError: (Object error, StackTrace stackTrace) {
        _setStatus(ChatConnectionStatus.disconnected);
        _messagesController.addError(error, stackTrace);
      },
      onDone: () => _setStatus(ChatConnectionStatus.disconnected),
    );
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    unawaited(disconnect());
    if (!_messagesController.isClosed) _messagesController.close();
    if (!_statusController.isClosed) _statusController.close();
  }

  void _setStatus(ChatConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
