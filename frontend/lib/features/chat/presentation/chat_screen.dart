import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_message.dart';
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
      appBar: AppBar(title: Text(widget.args.title)),
      body: Column(
        children: [
          if (_status != ChatConnectionStatus.connected)
            _StatusBanner(status: _status),
          Expanded(
            child: itemCount == 0
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final adjusted = index - leadingCount;
                      if (adjusted < _messages.length) {
                        return _MessageTile(message: _messages[adjusted]);
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(hintText: 'Message'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
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

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_senderLabel(message.senderKind),
              style: Theme.of(context).textTheme.labelSmall),
          Text(message.body),
        ],
      ),
    );
  }

  String _senderLabel(SenderKind kind) {
    switch (kind) {
      case SenderKind.guide:
        return 'Guide';
      case SenderKind.interpreter:
        return 'Interpreter';
      case SenderKind.listener:
        return 'Listener';
    }
  }
}

/// A message this screen just tried to send - shown immediately, before
/// (or instead of) server confirmation. While sending it looks like a
/// normal message with no failure UI; if the send failed, it shows the
/// error plus retry/dismiss so the user never has to retype it.
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
    final error = pending.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You', style: Theme.of(context).textTheme.labelSmall),
          Text(pending.body),
          if (error == null)
            Text(
              'Sending...',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            )
          else ...[
            Text(
              'Failed to send: ${apiErrorMessage(error)}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            Row(
              children: [
                TextButton(onPressed: onRetry, child: const Text('Retry')),
                TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
