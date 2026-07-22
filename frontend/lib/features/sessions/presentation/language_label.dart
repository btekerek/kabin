import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_providers.dart';

/// "Turkish (TR)" once the language registry (languagesProvider, via
/// languageNamesProvider) has resolved this code's name; just "TR" -
/// the bare code, same as before - while it's still loading or if the
/// code isn't in the registry. Never blocks on the fetch.
String languageDisplayLabel(Map<String, String> languageNames, String code) {
  final name = languageNames[code];
  return name == null ? code : '$name ($code)';
}

/// Widget form of [languageDisplayLabel] for the common case of just
/// wanting a Text with this styling - use the plain function instead
/// when the display string needs to be embedded in something else
/// (an AppBar title, an AppStrings-interpolated label, etc).
class LanguageLabel extends ConsumerWidget {
  const LanguageLabel(this.code, {super.key, this.style});

  final String code;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(languageNamesProvider);
    return Text(languageDisplayLabel(names, code), style: style);
  }
}
