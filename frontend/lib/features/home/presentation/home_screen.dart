import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/profile_menu.dart';
import '../../../l10n/locale_providers.dart';

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
    final t = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const KabinAppBarTitle('Kabin'),
        actions: const [
          LanguageMenu(),
          SizedBox(width: 4),
          ProfileMenu(),
          SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('/sessions'),
                  icon: const Icon(Icons.mic_outlined),
                  label: Text(t.createManageSessionButton),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/interpret'),
                  icon: const Icon(Icons.headset_mic_outlined),
                  label: Text(t.joinAsInterpreterButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
