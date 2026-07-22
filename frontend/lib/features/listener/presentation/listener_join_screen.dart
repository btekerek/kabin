import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../l10n/locale_providers.dart';
import 'listener_join_body.dart';

/// No account needed - a Listener identifies themselves with a PIN
/// (found via SessionLookupView) and a persisted UUID (ListenerIdentity),
/// never a login.
///
/// Standalone route ('/join') for direct deep links; LandingScreen embeds
/// ListenerJoinBody directly as its listener-first tab instead of
/// pushing here.
class ListenerJoinScreen extends ConsumerWidget {
  const ListenerJoinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(t.joinSessionTitle),
        actions: const [LanguageMenu()],
      ),
      body: const ListenerJoinBody(),
    );
  }
}
