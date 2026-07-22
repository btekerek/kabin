import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/locale_providers.dart';
import '../data/chat_socket.dart';
import '../domain/chat_target.dart';
import 'chat_args.dart';

/// Floating action button that opens chat, showing an unread-count
/// badge while it's closed. Keeps its own lightweight ChatSocket
/// connection(s) open just to count incoming messages - separate from
/// ChatScreen's own ChatControllers+ChatSockets, which own history/send
/// when chat is actually open. Opens a second socket for the channel
/// scope too when [ChatArgs.channelId] is set, so the badge reflects
/// unread messages from either tab.
class ChatFab extends ConsumerStatefulWidget {
  const ChatFab({super.key, required this.args});

  final ChatArgs args;

  @override
  ConsumerState<ChatFab> createState() => _ChatFabState();
}

class _ChatFabState extends ConsumerState<ChatFab> {
  final _generalSocket = ChatSocket();
  ChatSocket? _channelSocket;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _generalSocket.messages.listen((_) {
      if (mounted) setState(() => _unread++);
    });
    _generalSocket.connect(
      target: ChatTarget.general(widget.args.sessionId),
      accessToken: widget.args.accessToken,
    );

    final channelId = widget.args.channelId;
    if (channelId != null) {
      final socket = ChatSocket();
      _channelSocket = socket;
      socket.messages.listen((_) {
        if (mounted) setState(() => _unread++);
      });
      socket.connect(
        target: ChatTarget.channel(channelId),
        accessToken: widget.args.accessToken,
      );
    }
  }

  Future<void> _open() async {
    setState(() => _unread = 0);
    await context.push('/chat', extra: widget.args);
    if (mounted) setState(() => _unread = 0);
  }

  @override
  void dispose() {
    _generalSocket.dispose();
    _channelSocket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    return FloatingActionButton(
      tooltip: t.chatLabel,
      onPressed: _open,
      child: Badge(
        label: Text('$_unread'),
        isLabelVisible: _unread > 0,
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}
