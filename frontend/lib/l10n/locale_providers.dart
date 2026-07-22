import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_strings.dart';

const _prefsKey = 'kabin.app_language';

/// The user's chosen app language - matches the device's language on
/// first launch (Turkish device -> Turkish app, anything else ->
/// English), then remembers whatever's picked manually in Profile from
/// then on, the same shared_preferences persistence pattern as
/// ListenerIdentity's UUID.
final appLanguageProvider =
    AsyncNotifierProvider<AppLanguageController, AppLanguage>(
        AppLanguageController.new);

class AppLanguageController extends AsyncNotifier<AppLanguage> {
  @override
  Future<AppLanguage> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null) return AppLanguage.fromCode(stored);

    final deviceCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return AppLanguage.fromCode(deviceCode);
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, language.code);
    state = AsyncData(language);
  }
}

/// The current string catalog, ready to read synchronously - screens
/// shouldn't need to unwrap an AsyncValue just to show text. Defaults to
/// English for the brief moment before shared_preferences resolves.
final appStringsProvider = Provider<AppStrings>((ref) {
  final language =
      ref.watch(appLanguageProvider).valueOrNull ?? AppLanguage.english;
  return AppStrings(language);
});
