import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_language.dart';
import '../../l10n/locale_providers.dart';

/// The app-wide language switcher - lives in the AppBar next to
/// ProfileMenu on every screen (not buried in the Profile page, where
/// nobody would find it - see profile_screen.dart's history). Same
/// PopupMenuButton pattern as ProfileMenu for visual consistency.
class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage =
        ref.watch(appLanguageProvider).valueOrNull ?? AppLanguage.english;
    final t = ref.watch(appStringsProvider);

    return PopupMenuButton<AppLanguage>(
      tooltip: t.languageMenuTooltip,
      icon: const Icon(Icons.language),
      onSelected: (language) {
        ref.read(appLanguageProvider.notifier).setLanguage(language);
      },
      itemBuilder: (context) => [
        for (final language in AppLanguage.values)
          PopupMenuItem(
            value: language,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: language == currentLanguage
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(language.nativeName),
              ],
            ),
          ),
      ],
    );
  }
}
