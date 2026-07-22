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

  // Shared across auth screens
  String get passwordLabel => _pick('Password', 'Şifre');
  String get passwordRequired => _pick('Password is required', 'Şifre gerekli');
  String get showPasswordTooltip => _pick('Show password', 'Şifreyi göster');
  String get hidePasswordTooltip => _pick('Hide password', 'Şifreyi gizle');

  // Login screen
  String get emailOrUsernameLabel =>
      _pick('Email or username', 'E-posta veya kullanıcı adı');
  String get emailOrUsernameRequired => _pick(
      'Email or username is required', 'E-posta veya kullanıcı adı gerekli');
  String get logIn => _pick('LOG IN', 'GİRİŞ YAP');
  String get noAccountRegisterPrompt =>
      _pick("Don't have an account? Register", 'Hesabın yok mu? Kayıt ol');
  String get listenerJoinPrompt => _pick('Just here to listen? Join with a PIN',
      'Sadece dinlemek mi istiyorsun? PIN ile katıl');

  // Register screen
  String get createAccountTitle => _pick('Create an account', 'Hesap oluştur');
  String get emailLabel => _pick('Email', 'E-posta');
  String get emailRequired => _pick('Email is required', 'E-posta gerekli');
  String get usernameOptionalLabel =>
      _pick('Username (optional)', 'Kullanıcı adı (opsiyonel)');
  String get confirmPasswordLabel =>
      _pick('Confirm password', 'Şifreyi onayla');
  String get registerButton => _pick('REGISTER', 'KAYIT OL');
  String get alreadyHaveAccountPrompt => _pick(
      'Already have an account? Log in', 'Zaten bir hesabın var mı? Giriş yap');

  // Verify-email screen
  String get verifyEmailTitle =>
      _pick('Verify your email', 'E-postanı doğrula');
  String codeSentMessage(String email) => _pick(
      'We sent a 6-digit code to $email.',
      '$email adresine 6 haneli bir kod gönderdik.');
  String get verificationCodeLabel =>
      _pick('Verification code', 'Doğrulama kodu');
  String get enterSixDigitCode =>
      _pick('Enter the 6-digit code', '6 haneli kodu gir');
  String get verifyButton => _pick('VERIFY', 'DOĞRULA');
  String get resendCodePrompt =>
      _pick("Didn't get a code? Resend", 'Kod gelmedi mi? Tekrar gönder');
  String get resendCodeSent => _pick('Code sent - check your inbox.',
      'Kod gönderildi - gelen kutunu kontrol et.');
}
