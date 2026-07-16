import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/agora/agora_channel_controller.dart';
import '../../../core/errors/api_error_message.dart';
import '../state/interpreter_providers.dart';
import 'broadcasting_args.dart';

/// Owns one AgoraChannelController for the lifetime of this screen, same
/// lifecycle reasoning as ListeningScreen. Unlike the Listener flow,
/// leaving here also has to release the channel claim server-side
/// (ChannelLeaveView) so another interpreter can pick it up - that's why
/// this is a ConsumerStatefulWidget rather than plain StatefulWidget.
class BroadcastingScreen extends ConsumerStatefulWidget {
  const BroadcastingScreen({super.key, required this.args});

  final BroadcastingArgs args;

  @override
  ConsumerState<BroadcastingScreen> createState() =>
      _BroadcastingScreenState();
}

class _BroadcastingScreenState extends ConsumerState<BroadcastingScreen> {
  final _controller = AgoraChannelController();
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
    try {
      await _controller.join(
        appId: widget.args.joinResult.joinResult.agoraAppId,
        channelName: widget.args.joinResult.joinResult.agoraChannelName,
        token: widget.args.joinResult.joinResult.agoraToken,
        asBroadcaster: true,
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

  /// Releasing the claim (ChannelLeaveView) is not best-effort: if it
  /// fails, another interpreter can't pick up this channel, so the
  /// failure is surfaced and the user can retry rather than the screen
  /// silently popping as if the release had succeeded. _controller.leave()
  /// is idempotent (a no-op once the engine is already released), so
  /// retrying after a partial failure is safe.
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.args.joinResult.channel.language)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
