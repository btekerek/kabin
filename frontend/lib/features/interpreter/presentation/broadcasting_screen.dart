import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/agora/agora_channel_controller.dart';
import '../../../core/agora/agora_dual_channel_controller.dart';
import '../../../core/errors/api_error_message.dart';
import '../../auth/state/auth_providers.dart';
import '../../chat/presentation/chat_args.dart';
import '../state/interpreter_providers.dart';
import 'broadcasting_args.dart';

class BroadcastingScreen extends ConsumerStatefulWidget {
  const BroadcastingScreen({super.key, required this.args});

  final BroadcastingArgs args;

  @override
  ConsumerState<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends ConsumerState<BroadcastingScreen> {
  final _controller = AgoraDualChannelController();
  Object? _connectError;
  Object? _leaveError;
  bool _muted = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final source = widget.args.joinResult.source;
    try {
      await _controller.join(
        appId: widget.args.joinResult.joinResult.agoraAppId,
        primaryChannelName: widget.args.joinResult.joinResult.agoraChannelName,
        primaryToken: widget.args.joinResult.joinResult.agoraToken,
        secondaryChannelName: source?.agoraChannelName,
        secondaryToken: source?.agoraToken,
      );
    } catch (error) {
      if (mounted) setState(() => _connectError = error);
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _controller.setMicMuted(next);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _leave() async {
    setState(() {
      _leaving = true;
      _leaveError = null;
    });
    try {
      await _controller.leave();
      await ref
          .read(interpreterRepositoryProvider)
          .leave(widget.args.interpreterCode);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _leaveError = error);
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSource = widget.args.joinResult.source != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.args.joinResult.channel.language)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<AgoraConnectionStatus>(
                stream: _controller.primaryStatusStream,
                initialData: _controller.primaryStatus,
                builder: (context, snapshot) =>
                    Text(_statusLabel(snapshot.data)),
              ),
              const SizedBox(height: 8),
              if (hasSource)
                StreamBuilder<AgoraConnectionStatus>(
                  stream: _controller.secondaryStatusStream,
                  initialData: _controller.secondaryStatus,
                  builder: (context, snapshot) {
                    final status = snapshot.data;
                    return Column(
                      children: [
                        Text(
                          'Original audio: ${_statusLabel(status)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (status == AgoraConnectionStatus.failed)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              'Could not hear the original audio. Check your connection and try again.',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  },
                )
              else
                Text(
                  'This is the original audio channel.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (_connectError != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Could not connect. Check your connection and try again.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_leaveError != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Could not leave: ${apiErrorMessage(_leaveError!)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _leaving ? null : _toggleMute,
                icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                label: Text(_muted ? 'Unmute' : 'Mute'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push(
                  '/chat',
                  extra: ChatArgs(
                    sessionId: widget.args.joinResult.channel.sessionId,
                    socketQueryParams: {
                      'token': ref.read(authSessionProvider).accessToken ?? '',
                    },
                    title: 'Chat',
                  ),
                ),
                child: const Text('Chat'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _leaving ? null : _leave,
                child: const Text('Leave'),
              ),
            ],
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
        return 'Broadcasting';
      case AgoraConnectionStatus.failed:
        return 'Connection failed';
      case AgoraConnectionStatus.disconnected:
      case null:
        return 'Disconnected';
    }
  }
}
