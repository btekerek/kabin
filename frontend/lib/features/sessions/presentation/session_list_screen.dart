import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/content_column.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/profile_menu.dart';
import '../domain/session.dart';
import '../state/session_providers.dart';

class SessionListScreen extends ConsumerWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const KabinAppBarTitle('Your sessions'),
        actions: const [
          LanguageMenu(),
          SizedBox(width: 4),
          ProfileMenu(),
          SizedBox(width: 4),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Text(
                'No sessions yet. Create one to get started.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(sessionListProvider.notifier).refresh(),
            child: ContentColumn(
              maxWidth: 680,
              padding: EdgeInsets.zero,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sessions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _SessionTile(session: sessions[index]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sessions/create'),
        icon: const Icon(Icons.add),
        label: const Text('NEW SESSION'),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(session.name),
        subtitle: Text(
            'Code ${session.listenerCode} · ${_statusLabel(session.status)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/sessions/${session.id}'),
      ),
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
