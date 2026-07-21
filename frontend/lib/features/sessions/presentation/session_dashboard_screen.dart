import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/agora/agora_channel_controller.dart';
import '../../../core/errors/api_error_message.dart';
import '../../auth/state/auth_providers.dart';
import '../../chat/presentation/chat_args.dart';
import '../domain/channel.dart';
import '../domain/session.dart';
import '../state/session_providers.dart';

class SessionDashboardScreen extends ConsumerWidget {
  const SessionDashboardScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Session')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (session) => _DashboardBody(session: session),
      ),
    );
  }
}

/// A ConsumerStatefulWidget (not just ConsumerWidget) because it owns an
/// AgoraChannelController for the Guide's own mic - same "one screen,
/// one connection, disposed on exit" lifecycle as ListeningScreen/
/// BroadcastingScreen. Flutter reuses this State across rebuilds driven
/// by sessionDetailProvider (e.g. after start/stop/end refetches the
/// session), so the live mic connection survives those, and is only
/// ever torn down when the dashboard itself is left.
class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({required this.session});

  final Session session;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  final _micController = AgoraChannelController();
  bool _micConnecting = false;
  bool _muted = false;
  Object? _micError;

  Future<void> _goLive() async {
    setState(() {
      _micConnecting = true;
      _micError = null;
    });
    try {
      final result = await ref
          .read(sessionRepositoryProvider)
          .broadcast(widget.session.id);
      await _micController.join(
        appId: result.agoraAppId,
        channelName: result.agoraChannelName,
        token: result.agoraToken,
        asBroadcaster: true,
      );
    } catch (error) {
      setState(() => _micError = error);
    } finally {
      if (mounted) setState(() => _micConnecting = false);
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _micController.setMicMuted(next);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _stopBroadcasting() async {
    await _micController.leave();
    if (mounted) setState(() => _muted = false);
  }

  @override
  void dispose() {
    _micController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final controller = ref.read(sessionDetailProvider(session.id).notifier);
    final detailState = ref.watch(sessionDetailProvider(session.id));
    final isTransitioning = detailState.isLoading;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(session.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Status: ${_statusLabel(session.status)}'),
        const SizedBox(height: 24),
        _CodeCard(
          label: 'Listener PIN',
          code: session.listenerCode,
          description: 'Anyone in the room enters this to join as a listener.',
        ),
        const SizedBox(height: 24),
        Text('Your mic', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _MicControl(
          status: _micController.status,
          statusStream: _micController.statusStream,
          connecting: _micConnecting,
          muted: _muted,
          sessionActive: session.status == SessionStatus.active,
          onGoLive: _goLive,
          onToggleMute: _toggleMute,
          onStop: _stopBroadcasting,
        ),
        if (_micError != null) ...[
          const SizedBox(height: 8),
          Text(
            apiErrorMessage(_micError!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        Text('Channels', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final channel in session.channels) _ChannelTile(channel: channel),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (session.canStart)
              FilledButton(
                onPressed: isTransitioning ? null : controller.start,
                child: const Text('Start'),
              ),
            if (session.canStop)
              OutlinedButton(
                onPressed: isTransitioning ? null : controller.stop,
                child: const Text('Stop'),
              ),
            if (session.canEnd)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: isTransitioning ? null : controller.end,
                child: const Text('End session'),
              ),
            OutlinedButton(
              onPressed: () => context.push(
                '/chat',
                extra: ChatArgs(
                  sessionId: session.id,
                  socketQueryParams: {
                    'token': ref.read(authSessionProvider).accessToken ?? '',
                  },
                  title: 'Chat - ${session.name}',
                ),
              ),
              child: const Text('Chat'),
            ),
          ],
        ),
        if (detailState.hasError) ...[
          const SizedBox(height: 16),
          Text(
            apiErrorMessage(detailState.error as Object),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  String _statusLabel(SessionStatus status) {
    switch (status) {
      case SessionStatus.notStarted:
        return 'Not started';
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.ended:
        return 'Ended';
    }
  }
}

class _MicControl extends StatelessWidget {
  const _MicControl({
    required this.status,
    required this.statusStream,
    required this.connecting,
    required this.muted,
    required this.sessionActive,
    required this.onGoLive,
    required this.onToggleMute,
    required this.onStop,
  });

  final AgoraConnectionStatus status;
  final Stream<AgoraConnectionStatus> statusStream;
  final bool connecting;
  final bool muted;
  final bool sessionActive;
  final VoidCallback onGoLive;
  final VoidCallback onToggleMute;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AgoraConnectionStatus>(
      stream: statusStream,
      initialData: status,
      builder: (context, snapshot) {
        final current = snapshot.data ?? AgoraConnectionStatus.disconnected;
        final isLive = current == AgoraConnectionStatus.connected ||
            current == AgoraConnectionStatus.connecting;

        if (!isLive) {
          if (!sessionActive) {
            return const SizedBox.shrink();
          }
          return FilledButton.icon(
            onPressed: connecting ? null : onGoLive,
            icon: const Icon(Icons.mic_outlined),
            label: const Text('Go live'),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_statusLabel(current)),
            if (current == AgoraConnectionStatus.connected) ...[
              FilledButton.icon(
                onPressed: onToggleMute,
                icon: Icon(muted ? Icons.mic_off : Icons.mic),
                label: Text(muted ? 'Unmute' : 'Mute'),
              ),
              OutlinedButton(
                onPressed: onStop,
                child: const Text('Stop broadcasting'),
              ),
            ],
          ],
        );
      },
    );
  }

  String _statusLabel(AgoraConnectionStatus status) {
    switch (status) {
      case AgoraConnectionStatus.connecting:
        return 'Connecting...';
      case AgoraConnectionStatus.connected:
        return 'Live';
      case AgoraConnectionStatus.failed:
        return 'Connection failed';
      case AgoraConnectionStatus.disconnected:
        return 'Off';
    }
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard(
      {required this.label, required this.code, required this.description});

  final String label;
  final String code;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  Text(code, style: Theme.of(context).textTheme.headlineMedium),
                  Text(description,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final code = channel.interpreterCode;
    return ListTile(
      title: Text(channel.language + (channel.isSource ? ' (source)' : '')),
      subtitle: code != null ? Text('Interpreter code: $code') : null,
      trailing: code != null
          ? IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            )
          : null,
    );
  }
}
