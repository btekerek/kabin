import 'dart:async';

import '../data/chat_repository.dart';
import '../data/chat_socket.dart';
import '../domain/message.dart';

/// A message this screen just tried to send, before (or instead of) it's
/// confirmed by the server. Shown at the end of the message list while
/// [error] is null; if [error] is set, the send failed and the UI should
/// offer retry/dismiss rather than silently dropping it - the user
/// shouldn't have to retype a message that failed to send.
class PendingMessage {
  PendingMessage({required this.localId, required this.body, this.listenerUuid});

  final int localId;
  final String body;
  final String? listenerUuid;
  Object? error;
}

/// Combines the REST message history with the live WebSocket feed for
/// one chat screen's lifetime. Deliberately a plain class rather than a
/// Riverpod AsyncNotifier - same reasoning as AgoraChannelController
/// (see ListeningScreen/BroadcastingScreen): the underlying ChatSocket
/// is a real connection tied 1:1 to a screen being open, created on
/// entry and disposed on exit, not something Riverpod's provider
/// lifecycle needs to own. A screen constructs one directly, calls
/// [connect] from initState, and calls [dispose] from its own dispose.
///
/// Generic over [socketQueryParams] / a sender's `listenerUuid` so Guide
/// and Interpreter screens both reuse this unchanged - only the auth
/// mechanism differs between them (see ChatConsumer._authorize).
///
/// Confirmed messages are kept in a map keyed by server id, not a plain
/// list, so a message can be upserted from either of two sources - the
/// REST response to a successful send, or the WebSocket's later echo of
/// the same message - without showing it twice. This also means a sent
/// message appears immediately (as soon as the REST call returns)
/// instead of waiting on the round trip through the channel layer.
class ChatController {
  ChatController({required ChatRepository repository, required this.sessionId})
      : _repository = repository;

  final ChatRepository _repository;
  final int sessionId;
  final ChatSocket _socket = ChatSocket();

  final Map<int, ChatMessage> _byId = {};
  final _messagesController = StreamController<List<ChatMessage>>.broadcast();
  StreamSubscription<ChatMessage>? _socketSubscription;

  final List<PendingMessage> _pending = [];
  final _pendingController = StreamController<List<PendingMessage>>.broadcast();
  int _nextLocalId = 0;

  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<ChatConnectionStatus> get statusStream => _socket.statusStream;
  Stream<List<PendingMessage>> get pendingStream => _pendingController.stream;

  List<ChatMessage> get messages => _sortedMessages();
  List<PendingMessage> get pending => List.unmodifiable(_pending);

  /// Fetches history, then opens the live socket. [socketQueryParams] is
  /// `{'token': accessToken}` for guide/interpreter.
  Future<void> connect(Map<String, String> socketQueryParams) async {
    final history = await _repository.history(sessionId);
    for (final message in history) {
      _byId[message.id] = message;
    }
    _messagesController.add(_sortedMessages());

    _socketSubscription = _socket.messages.listen(_upsert);
    _socket.connect(sessionId: sessionId, queryParams: socketQueryParams);
  }

  /// Shows [body] immediately as a pending entry, then sends it. On
  /// success the real message is upserted right away (not left to wait
  /// for the WebSocket echo, which may arrive noticeably later) and the
  /// pending entry is cleared. On failure the pending entry stays,
  /// marked with [PendingMessage.error], so [retry] can resend the exact
  /// same body without the user retyping it.
  Future<void> send({required String body, String? listenerUuid}) {
    final pending = PendingMessage(
      localId: _nextLocalId++,
      body: body,
      listenerUuid: listenerUuid,
    );
    _pending.add(pending);
    _emitPending();
    return _attemptSend(pending);
  }

  Future<void> retry(PendingMessage pending) {
    pending.error = null;
    _emitPending();
    return _attemptSend(pending);
  }

  void dismiss(PendingMessage pending) {
    _pending.remove(pending);
    _emitPending();
  }

  Future<void> _attemptSend(PendingMessage pending) async {
    try {
      final message = await _repository.send(
        sessionId: sessionId,
        body: pending.body,
        listenerUuid: pending.listenerUuid,
      );
      _upsert(message);
      _pending.remove(pending);
      _emitPending();
    } catch (error) {
      pending.error = error;
      _emitPending();
      rethrow;
    }
  }

  void _upsert(ChatMessage message) {
    _byId[message.id] = message;
    _messagesController.add(_sortedMessages());
  }

  List<ChatMessage> _sortedMessages() {
    final list = _byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  void _emitPending() {
    _pendingController.add(List.unmodifiable(_pending));
  }

  void dispose() {
    unawaited(_socketSubscription?.cancel());
    _socket.dispose();
    if (!_messagesController.isClosed) _messagesController.close();
    if (!_pendingController.isClosed) _pendingController.close();
  }
}
