import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/profile_menu.dart';
import '../../auth/state/auth_providers.dart';
import '../data/chat_socket.dart';
import '../domain/message.dart';
import '../state/chat_controller.dart';
import '../state/chat_providers.dart';
import 'chat_args.dart';

/// One screen reused by Guide and Interpreter - both read/send the same
/// session's messages (see IsSessionParticipant on the backend); only
/// [ChatArgs.socketQueryParams] differs between them. Owns a
/// ChatController for the screen's lifetime, same pattern as
/// ListeningScreen/BroadcastingScreen owning an AgoraChannelController.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.args});

  final ChatArgs args;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatController _controller;
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = const [];
  List<PendingMessage> _pending = const [];
  ChatConnectionStatus _status = ChatConnectionStatus.connecting;
  bool _loadingOlder = false;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(
      repository: ref.read(chatRepositoryProvider),
      sessionId: widget.args.sessionId,
    );
    _controller.messagesStream.listen((messages) {
      if (mounted) setState(() => _messages = messages);
    });
    _controller.pendingStream.listen((pending) {
      if (mounted) setState(() => _pending = pending);
    });
    _controller.statusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });
    _controller.connect(widget.args.socketQueryParams);
    _scrollController.addListener(_onScroll);
  }

  /// Messages render oldest-first (index 0 at the top), so scrolling
  /// toward minScrollExtent is scrolling toward the oldest message
  /// currently loaded - that's when it's time to fetch the page before it.
  void _onScroll() {
    const threshold = 200.0;
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + threshold) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_controller.hasMoreHistory) return;
    setState(() => _loadingOlder = true);
    try {
      await _controller.loadOlder();
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _send() {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    _bodyController.clear();
    // Failure is already captured on the PendingMessage itself (see
    // ChatController.send/_attemptSend) and rendered by _PendingTile's
    // retry/dismiss controls - catching here just stops the rethrow from
    // becoming an unhandled async error, it isn't swallowing anything
    // the user can't already see and act on.
    unawaited(
        _controller.send(body: body, listenerUuid: widget.args.listenerUuid));
  }

  /// Whether [message] was sent by the person looking at this screen -
  /// drives which side of the thread it renders on. Listeners are
  /// identified by [ChatArgs.listenerUuid] (no account); Guide/Interpreter
  /// by the authenticated user's id, since either can be viewing this
  /// same shared screen (see class doc).
  bool _isMine(ChatMessage message) {
    final listenerUuid = widget.args.listenerUuid;
    if (listenerUuid != null) {
      return message.senderListenerUuid == listenerUuid;
    }
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;
    return currentUserId != null && message.senderId == currentUserId;
  }

  @override
  void dispose() {
    _controller.dispose();
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leadingCount = _loadingOlder ? 1 : 0;
    final itemCount = leadingCount + _messages.length + _pending.length;
    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(widget.args.title),
        // Listeners have no account (see ADR-002) - the menu only makes
        // sense for the Guide/Interpreter side of this shared screen.
        actions: widget.args.listenerUuid == null
            ? const [ProfileMenu(), SizedBox(width: 4)]
            : null,
      ),
      body: Column(
        children: [
          if (_status != ChatConnectionStatus.connected)
            _StatusBanner(status: _status),
          Expanded(
            child: itemCount == 0
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (_loadingOlder && index == 0) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final adjusted = index - leadingCount;
                          if (adjusted < _messages.length) {
                            final message = _messages[adjusted];
                            return _MessageTile(
                              message: message,
                              isMine: _isMine(message),
                            );
                          }
                          final pending = _pending[adjusted - _messages.length];
                          return _PendingTile(
                            pending: pending,
                            onRetry: () => _controller.retry(pending),
                            onDismiss: () => _controller.dismiss(pending),
                          );
                        },
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _bodyController,
                          decoration:
                              const InputDecoration(hintText: 'Message'),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.send),
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final ChatConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final label = status == ChatConnectionStatus.connecting
        ? 'Connecting...'
        : 'Connection lost';
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}

/// Chat-app convention: your own messages sit right-aligned in the
/// accent color, everyone else's sit left-aligned in a neutral tint with
/// a sender label above - makes it possible to scan a fast-moving thread
/// without reading every label.
class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine) ...[
                  Text(_senderLabel(message),
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.body,
                    style: TextStyle(
                        color: isMine ? scheme.onPrimary : scheme.onSurface),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeLabel(message.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _senderLabel(ChatMessage message) {
    final name = message.senderName;
    if (name != null && name.isNotEmpty) return name;
    switch (message.senderKind) {
      case SenderKind.guide:
        return 'GUIDE';
      case SenderKind.interpreter:
        return 'INTERPRETER';
      case SenderKind.listener:
        return 'LISTENER';
    }
  }

  String _timeLabel(DateTime createdAt) {
    final local = createdAt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// A message this screen just tried to send - shown immediately, before
/// (or instead of) server confirmation. Always rendered on "my" side
/// since only the sender ever sees their own pending state. While
/// sending it looks like a normal message with no failure UI; if the
/// send failed, it shows the error plus retry/dismiss so the user never
/// has to retype it.
class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.pending,
    required this.onRetry,
    required this.onDismiss,
  });

  final PendingMessage pending;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = pending.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: error != null
                        ? scheme.errorContainer
                        : scheme.primary.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    pending.body,
                    style: TextStyle(
                        color: error != null
                            ? scheme.onErrorContainer
                            : scheme.onPrimary),
                  ),
                ),
                const SizedBox(height: 2),
                if (error == null)
                  Text(
                    'Sending...',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.outline, fontStyle: FontStyle.italic),
                  )
                else ...[
                  Text(
                    'Failed to send: ${apiErrorMessage(error)}',
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                          onPressed: onRetry, child: const Text('RETRY')),
                      TextButton(
                          onPressed: onDismiss, child: const Text('DISMISS')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
