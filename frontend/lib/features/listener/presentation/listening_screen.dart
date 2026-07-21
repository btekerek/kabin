import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/agora/agora_channel_controller.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import 'listening_args.dart';

/// Owns one AgoraChannelController for the lifetime of this screen -
/// joins on entry (audience role, no mic), leaves and disposes on exit.
/// This screen deliberately doesn't use Riverpod for the connection
/// itself: the controller's lifecycle is tied 1:1 to this widget's
/// lifecycle, which is exactly what StatefulWidget's initState/dispose
/// already model - a provider would just be indirection here.
class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key, required this.args});

  final ListeningArgs args;

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  final _controller = AgoraChannelController();
  Object? _connectError;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _controller.join(
        appId: widget.args.joinResult.agoraAppId,
        channelName: widget.args.joinResult.agoraChannelName,
        token: widget.args.joinResult.agoraToken,
        asBroadcaster: false,
      );
    } catch (error) {
      if (mounted) setState(() => _connectError = error);
    }
  }

  Future<void> _leave() async {
    await _controller.leave();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: KabinAppBarTitle(widget.args.sessionName)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.args.channelLanguage,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                StreamBuilder<AgoraConnectionStatus>(
                  stream: _controller.statusStream,
                  initialData: _controller.status,
                  builder: (context, snapshot) =>
                      Text(_statusLabel(snapshot.data)),
                ),
                if (_connectError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Could not connect. Check your connection and try again.',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton(onPressed: _leave, child: const Text('LEAVE')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(AgoraConnectionStatus? status) {
    switch (status) {
      case AgoraConnectionStatus.connecting:
        return 'Connecting...';
      case AgoraConnectionStatus.connected:
        return 'Listening';
      case AgoraConnectionStatus.failed:
        return 'Connection failed';
      case AgoraConnectionStatus.disconnected:
      case null:
        return 'Disconnected';
    }
  }
}
