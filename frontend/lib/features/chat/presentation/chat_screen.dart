import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_message.dart';
import '../data/chat_socket.dart';
import '../domain/message.dart';
import '../state/chat_controller.dart';
import '../state/chat_providers.dart';
import 'chat_args.dart';

/// One screen reused by all three roles - Guide, Interpreter, and
/// Listener all read/send the same session's messages (see
/// IsSessionParticipant on the backend); only [ChatArgs.socketQueryParams]
/// /[ChatArgs.listenerUuid] differ between them. Owns a ChatController
/// for the screen's lifetime, same pattern as ListeningScreen/
/// BroadcastingScreen owning an AgoraChannelController.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.args});

  final ChatArgs args;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatController _controller;
  final _bodyController = TextEditingController();

  List<ChatMessage> _messages = const [];
  ChatConnectionStatus _status = ChatConnectionStatus.connecting;
  Object? _sendError;
  bool _sending = false;

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
    _controller.statusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });
    _controller.connect(widget.args.socketQueryParams);
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await _controller.send(body: body, listenerUuid: widget.args.listenerUuid);
      _bodyController.clear();
    } catch (error) {
      setState(() => _sendError = error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.args.title)),
      body: Column(
        children: [
          if (_status != ChatConnectionStatus.connected) _StatusBanner(status: _status),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _MessageTile(message: _messages[index]),
                  ),
          ),
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                apiErrorMessage(_sendError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                      onSubmitted: (_) {
                        if (!_sending) _send();
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
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
    final label = status == ChatConnectionStatus.connecting ? 'Connecting...' : 'Connection lost';
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
          Text(_senderLabel(message.senderKind), style: Theme.of(context).textTheme.labelSmall),
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
