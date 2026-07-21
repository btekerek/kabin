import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/agora/agora_channel_controller.dart';
import '../../../core/agora/agora_dual_channel_controller.dart';
import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/big_mic_button.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/profile_menu.dart';
import '../../auth/state/auth_providers.dart';
import '../../chat/presentation/chat_args.dart';
import '../data/mic_presence_socket.dart';
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
  final _micPresence = MicPresenceSocket();
  final _liveInterpreterIds = <int>{};
  Object? _connectError;
  Object? _leaveError;
  bool _muted = true;
  bool _leaving = false;
  late String _sessionStatus;

  bool get _canBroadcast => _sessionStatus == 'active';

  @override
  void initState() {
    super.initState();
    _sessionStatus = widget.args.joinResult.channel.sessionStatus;
    _connect();
    _connectMicPresence();
  }

  void _connectMicPresence() {
    _micPresence.events.listen((event) {
      final myId = ref.read(authControllerProvider).valueOrNull?.id;
      if (event.userId == myId) return;
      setState(() {
        if (event.live) {
          _liveInterpreterIds.add(event.userId);
        } else {
          _liveInterpreterIds.remove(event.userId);
        }
      });
    });
    _micPresence.statusRequests.listen((_) {
      if (!_muted) _micPresence.sendMicState(true);
    });
    // Pushed instantly by _SessionTransitionView.after_transition when
    // the guide starts/stops/ends the session - lets the mic gate
    // unlock without a reconnect if the interpreter joined early.
    _micPresence.sessionStatusUpdates.listen((status) {
      if (mounted) setState(() => _sessionStatus = status);
    });
    _micPresence.connect(
      channelId: widget.args.joinResult.channel.id,
      accessToken: ref.read(authSessionProvider).accessToken ?? '',
    );
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
    _micPresence.sendMicState(!next);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _handleMicTap() async {
    if (_controller.primaryStatus == AgoraConnectionStatus.failed) {
      _connect();
      return;
    }
    if (_muted && _liveInterpreterIds.isNotEmpty) {
      final proceed = await _confirmBroadcastOverMic();
      if (proceed != true) return;
    }
    _toggleMute();
  }

  Future<bool?> _confirmBroadcastOverMic() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Another interpreter is live'),
        content: const Text(
            'Someone else is already broadcasting on this channel. Listeners will hear you both at once if you turn your mic on.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('TURN ON ANYWAY'),
          ),
        ],
      ),
    );
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
    _micPresence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSource = widget.args.joinResult.source != null;

    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(widget.args.joinResult.channel.language),
        actions: const [ProfileMenu(), SizedBox(width: 4)],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Chat',
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
        child: const Icon(Icons.chat_bubble_outline),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<AgoraConnectionStatus>(
                  stream: _controller.primaryStatusStream,
                  initialData: _controller.primaryStatus,
                  builder: (context, snapshot) =>
                      Text(_primaryStatusLabel(snapshot.data)),
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
                            'Original audio: ${_sourceAudioLabel(status)}',
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
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_leaveError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Could not leave: ${apiErrorMessage(_leaveError!)}',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                StreamBuilder<AgoraConnectionStatus>(
                  stream: _controller.primaryStatusStream,
                  initialData: _controller.primaryStatus,
                  builder: (context, snapshot) => BigMicButton(
                    status: snapshot.data ?? AgoraConnectionStatus.disconnected,
                    muted: _muted,
                    onTap: _leaving ? () {} : _handleMicTap,
                    enabled: _canBroadcast,
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: _leaving ? null : _leave,
                  child: const Text('LEAVE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _primaryStatusLabel(AgoraConnectionStatus? status) {
    switch (status) {
      case AgoraConnectionStatus.connecting:
        return 'Connecting...';
      case AgoraConnectionStatus.connected:
        return _muted ? 'Connected' : 'Broadcasting';
      case AgoraConnectionStatus.failed:
        return 'Connection failed';
      case AgoraConnectionStatus.disconnected:
      case null:
        return 'Disconnected';
    }
  }

  String _sourceAudioLabel(AgoraConnectionStatus? status) {
    final language = widget.args.joinResult.sourceLanguage ?? 'original';
    switch (status) {
      case AgoraConnectionStatus.connecting:
        return '$language (connecting...)';
      case AgoraConnectionStatus.failed:
        return '$language (connection failed)';
      case AgoraConnectionStatus.connected:
      case AgoraConnectionStatus.disconnected:
      case null:
        return language;
    }
  }
}
