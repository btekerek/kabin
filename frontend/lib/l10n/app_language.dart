/// The app's own UI language - separate from a session's spoken/
/// interpreted content languages (see backend's apps.core.languages,
/// which covers "essentially any real-world language" for that; this
/// is just what the app's own buttons/labels are written in).
///
/// Turkish and English only for now - more can be added later by adding
/// a case here and filling in the corresponding strings in
/// AppStrings, nothing structural needs to change.
enum AppLanguage {
  english('en'),
  turkish('tr');

  const AppLanguage(this.code);

  /// ISO 639-1 code - used for shared_preferences persistence and for
  /// matching against the device's own locale.
  final String code;

  /// Always shown in the language's own name (e.g. "Türkçe" even when
  /// the current UI language is English) - the standard convention for
  /// language pickers, since a translated label defeats the point of
  /// letting someone find their own language.
  String get nativeName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.turkish:
        return 'Türkçe';
    }
  }

  static AppLanguage fromCode(String code) => AppLanguage.values.firstWhere(
        (language) => language.code == code,
        orElse: () => AppLanguage.english,
      );
}
