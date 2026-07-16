import 'dart:async';

import '../data/chat_repository.dart';
import '../data/chat_socket.dart';
import '../domain/message.dart';

/// Combines the REST message history with the live WebSocket feed for
/// one chat screen's lifetime. Deliberately a plain class rather than a
/// Riverpod AsyncNotifier - same reasoning as AgoraChannelController
/// (see ListeningScreen/BroadcastingScreen): the underlying ChatSocket
/// is a real connection tied 1:1 to a screen being open, created on
/// entry and disposed on exit, not something Riverpod's provider
/// lifecycle needs to own. A screen constructs one directly, calls
/// [connect] from initState, and calls [dispose] from its own dispose.
///
/// Generic over [socketQueryParams] / [listenerUuid] so Guide,
/// Interpreter, and Listener screens all reuse this unchanged - only the
/// auth mechanism differs between them (see ChatConsumer._authorize).
class ChatController {
  ChatController({required ChatRepository repository, required this.sessionId})
      : _repository = repository;

  final ChatRepository _repository;
  final int sessionId;
  final ChatSocket _socket = ChatSocket();

  final _messagesController = StreamController<List<ChatMessage>>.broadcast();
  List<ChatMessage> _messages = const [];
  StreamSubscription<ChatMessage>? _socketSubscription;

  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<ChatConnectionStatus> get statusStream => _socket.statusStream;
  List<ChatMessage> get messages => _messages;

  /// Fetches history, then opens the live socket. [socketQueryParams] is
  /// `{'token': accessToken}` for guide/interpreter or
  /// `{'listener_uuid': uuid}` for a listener.
  Future<void> connect(Map<String, String> socketQueryParams) async {
    _messages = await _repository.history(sessionId);
    _messagesController.add(_messages);

    _socketSubscription = _socket.messages.listen((message) {
      _messages = [..._messages, message];
      _messagesController.add(_messages);
    });
    _socket.connect(sessionId: sessionId, queryParams: socketQueryParams);
  }

  /// REST is the only write path (see ChatConsumer) - the sent message
  /// arrives back through the socket like any other participant's
  /// message, so this doesn't append anything itself; appending here too
  /// would risk showing the sender's own message twice.
  Future<void> send({required String body, String? listenerUuid}) {
    return _repository.send(
      sessionId: sessionId,
      body: body,
      listenerUuid: listenerUuid,
    );
  }

  void dispose() {
    unawaited(_socketSubscription?.cancel());
    _socket.dispose();
    if (!_messagesController.isClosed) _messagesController.close();
  }
}
