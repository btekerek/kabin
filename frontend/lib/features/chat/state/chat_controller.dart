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
  PendingMessage(
      {required this.localId, required this.body, this.listenerUuid});

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

  static const int _pageSize = 50;
  bool _hasMoreHistory = true;
  bool _loadingOlder = false;

  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<ChatConnectionStatus> get statusStream => _socket.statusStream;
  Stream<List<PendingMessage>> get pendingStream => _pendingController.stream;

  List<ChatMessage> get messages => _sortedMessages();
  List<PendingMessage> get pending => List.unmodifiable(_pending);

  /// Whether there's an older page left to fetch via [loadOlder] - false
  /// once a page comes back shorter than the page size, meaning the
  /// beginning of the conversation has been reached.
  bool get hasMoreHistory => _hasMoreHistory;

  /// Fetches the most recent page of history, then opens the live
  /// socket. [socketQueryParams] is `{'token': accessToken}` for
  /// guide/interpreter. Only the most recent [_pageSize] messages load
  /// here - older ones are fetched on demand via [loadOlder], not all at
  /// once, so opening a long-running session's chat doesn't mean
  /// downloading its entire history up front.
  Future<void> connect(Map<String, String> socketQueryParams) async {
    final history = await _repository.history(sessionId, limit: _pageSize);
    _hasMoreHistory = history.length >= _pageSize;
    for (final message in history) {
      _byId[message.id] = message;
    }
    _messagesController.add(_sortedMessages());

    _socketSubscription = _socket.messages.listen(_upsert);
    _socket.connect(sessionId: sessionId, queryParams: socketQueryParams);
  }

  /// Fetches the page immediately before the oldest message currently
  /// loaded and prepends it. A no-op if a fetch is already in flight,
  /// [hasMoreHistory] is already false, or nothing has loaded yet (there
  /// being no "oldest" to page backward from before [connect] resolves).
  Future<void> loadOlder() async {
    if (_loadingOlder || !_hasMoreHistory) return;
    final sorted = _sortedMessages();
    if (sorted.isEmpty) return;

    _loadingOlder = true;
    try {
      final page = await _repository.history(
        sessionId,
        beforeId: sorted.first.id,
        limit: _pageSize,
      );
      _hasMoreHistory = page.length >= _pageSize;
      for (final message in page) {
        _byId[message.id] = message;
      }
      _messagesController.add(_sortedMessages());
    } finally {
      _loadingOlder = false;
    }
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

  /// Sorted by (createdAt, id) - a plain createdAt sort isn't enough on
  /// its own since two messages can share the same second in a live
  /// chat, and List.sort isn't guaranteed stable for ties. Breaking ties
  /// by id matches the backend's own ordering (Message.Meta.ordering =
  /// ["created_at", "id"]), so this can never reorder messages compared
  /// to what a fresh history() fetch would return.
  List<ChatMessage> _sortedMessages() {
    final list = _byId.values.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
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
