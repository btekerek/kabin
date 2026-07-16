import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../../auth/state/auth_providers.dart';
import '../domain/session.dart';
import '../state/session_providers.dart';

class SessionListScreen extends ConsumerWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
                child: Text('No sessions yet. Create one to get started.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(sessionListProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) =>
                  _SessionTile(session: sessions[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sessions/create'),
        icon: const Icon(Icons.add),
        label: const Text('New session'),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(session.name),
      subtitle: Text(
          'Code ${session.listenerCode} · ${_statusLabel(session.status)}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/sessions/${session.id}'),
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
