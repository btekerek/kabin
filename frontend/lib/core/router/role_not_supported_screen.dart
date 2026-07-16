import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/auth_providers.dart';

/// Only Guide screens exist so far (see ADR-007 - Interpreter and
/// Listener flows are later slices). An Interpreter account can still
/// log in against the same backend, so this screen exists to say so
/// plainly rather than dropping them into Guide-only screens that
/// would just 403 against the backend anyway.
class RoleNotSupportedScreen extends ConsumerWidget {
  const RoleNotSupportedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "This app doesn't have Interpreter screens yet.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
