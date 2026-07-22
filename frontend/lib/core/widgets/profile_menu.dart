import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/state/auth_providers.dart';
import '../../l10n/locale_providers.dart';

enum _ProfileAction { profile, logout }

class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(authControllerProvider).valueOrNull?.username;
    final initial = (username != null && username.isNotEmpty)
        ? username[0].toUpperCase()
        : '?';
    final t = ref.watch(appStringsProvider);

    return PopupMenuButton<_ProfileAction>(
      tooltip: t.account,
      onSelected: (action) {
        switch (action) {
          case _ProfileAction.profile:
            context.push('/profile');
          case _ProfileAction.logout:
            ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ProfileAction.profile,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(t.profile),
          ),
        ),
        PopupMenuItem(
          value: _ProfileAction.logout,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(t.logOut),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              child: Text(initial, style: const TextStyle(fontSize: 13)),
            ),
            if (username != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(username,
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ],
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
