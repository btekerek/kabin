import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/chat_socket.dart';
import 'chat_args.dart';

/// Floating action button that opens chat, showing an unread-count
/// badge while it's closed. Keeps its own lightweight ChatSocket
/// connection open just to count incoming messages - separate from
/// ChatScreen's own ChatController+ChatSocket, which owns history/send
/// when chat is actually open.
class ChatFab extends StatefulWidget {
  const ChatFab({super.key, required this.args});

  final ChatArgs args;

  @override
  State<ChatFab> createState() => _ChatFabState();
}

class _ChatFabState extends State<ChatFab> {
  final _socket = ChatSocket();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _socket.messages.listen((_) {
      if (mounted) setState(() => _unread++);
    });
    _socket.connect(
      sessionId: widget.args.sessionId,
      queryParams: widget.args.socketQueryParams,
    );
  }

  Future<void> _open() async {
    setState(() => _unread = 0);
    await context.push('/chat', extra: widget.args);
    if (mounted) setState(() => _unread = 0);
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: 'Chat',
      onPressed: _open,
      child: Badge(
        label: Text('$_unread'),
        isLabelVisible: _unread > 0,
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}
