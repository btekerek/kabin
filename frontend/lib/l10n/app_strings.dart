import 'app_language.dart';

/// The app's single string catalog (see README's project structure
/// note) - every UI string the app shows lives here as one `en`/`tr`
/// pair, rather than per-screen ARB files + codegen. Screens read it
/// via appStringsProvider (locale_providers.dart) instead of
/// AppLocalizations.of(context), which keeps it consistent with how
/// every other piece of app state already flows through Riverpod here.
///
/// Grown incrementally, screen by screen, rather than front-loaded -
/// each migration adds only the keys that screen actually needs.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String _pick(String en, String tr) =>
      language == AppLanguage.turkish ? tr : en;

  // Profile screen + account menu
  String get profile => _pick('Profile', 'Profil');
  String get account => _pick('Account', 'Hesap');
  String get logOut => _pick('Log out', 'Çıkış yap');
  String get usernameSectionHeader => _pick('USERNAME', 'KULLANICI ADI');
  String get usernameLabel => _pick('Username', 'Kullanıcı adı');
  String get usernameRequired =>
      _pick('Username is required', 'Kullanıcı adı gerekli');
  String get saveUsername => _pick('SAVE USERNAME', 'KULLANICI ADINI KAYDET');
  String get usernameUpdated =>
      _pick('Username updated.', 'Kullanıcı adı güncellendi.');
  String get changePasswordSectionHeader =>
      _pick('CHANGE PASSWORD', 'ŞİFRE DEĞİŞTİR');
  String get currentPasswordLabel => _pick('Current password', 'Mevcut şifre');
  String get currentPasswordRequired =>
      _pick('Current password is required', 'Mevcut şifre gerekli');
  String get newPasswordLabel => _pick('New password', 'Yeni şifre');
  String get newPasswordRequired =>
      _pick('New password is required', 'Yeni şifre gerekli');
  String get confirmNewPasswordLabel =>
      _pick('Confirm new password', 'Yeni şifreyi onayla');
  String get passwordsDoNotMatch =>
      _pick('Passwords do not match', 'Şifreler eşleşmiyor');
  String get updatePassword => _pick('UPDATE PASSWORD', 'ŞİFREYİ GÜNCELLE');
  String get comingSoon => _pick('Coming soon.', 'Yakında.');
  String get languageMenuTooltip => _pick('Language', 'Dil');
}
