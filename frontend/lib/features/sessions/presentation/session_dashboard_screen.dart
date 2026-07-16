import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      case SessionStatus.qaMode:
        return 'Q&A';
      case SessionStatus.ended:
        return 'Ended';
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
    return ListTile(
      title: Text(channel.language + (channel.isSource ? ' (source)' : '')),
      subtitle: Text('Interpreter code: ${channel.interpreterCode}'),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        tooltip: 'Copy',
        onPressed: () =>
            Clipboard.setData(ClipboardData(text: channel.interpreterCode)),
      ),
    );
  }
}
