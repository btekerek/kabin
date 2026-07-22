import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: KabinApp()));
}

class KabinApp extends ConsumerWidget {
  const KabinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Kabin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      // Single choke point for the Android 3-button/gesture nav bar: every
      // screen's content gets bottom padding equal to that system inset,
      // so buttons and list items never sit under it. Top is left alone -
      // each screen already handles its own AppBar/status-bar spacing.
      builder: (context, child) => SafeArea(
        top: false,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
