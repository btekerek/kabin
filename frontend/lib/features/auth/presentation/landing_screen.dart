import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../l10n/locale_providers.dart';
import '../../listener/presentation/listener_join_body.dart';
import 'login_screen.dart';

/// The app's landing screen when logged out. Listeners vastly outnumber
/// guides/interpreters, so the PIN-entry segment opens first (index 0) -
/// logging in/registering is one tap away on the second segment instead
/// of sharing the same form, where it was easy to lose the PIN field
/// under register/forgot-password links. Mirrors ChatScreen's General/
/// Channel tab pattern.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const KabinAppBarTitle('Kabin'),
        actions: const [LanguageMenu()],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t.listenTabLabel),
            Tab(text: t.logInTabLabel),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ListenerJoinBody(),
          LoginForm(),
        ],
      ),
    );
  }
}
