import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_providers.dart';

/// Post-login landing screen. There's no fixed account role (see
/// features/auth/domain/user.dart) - any logged in user can create a
/// session, becoming that session's owner, or claim an interpreter
/// channel on any session, so this screen just offers both paths
/// instead of routing by role (see app_router.dart's redirect logic,
/// which sends every logged-in user here rather than branching).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kabin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => context.push('/sessions'),
              icon: const Icon(Icons.mic_outlined),
              label: const Text('Create / manage a session'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/interpret'),
              icon: const Icon(Icons.headset_mic_outlined),
              label: const Text('Join as interpreter'),
            ),
          ],
        ),
      ),
    );
  }
}
