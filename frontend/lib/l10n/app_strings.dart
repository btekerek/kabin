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

  // Session status - two case variants (sentence case for the session
  // list, all-caps for the dashboard's pill) written by hand rather than
  // derived with .toUpperCase(): Dart's toUpperCase() is locale-unaware,
  // and Turkish's dotted/dotless I pairs (i/İ, ı/I) don't uppercase
  // correctly under that ASCII-style rule.
  String get statusNotStarted => _pick('Not started', 'Başlamadı');
  String get statusActive => _pick('Active', 'Aktif');
  String get statusEnded => _pick('Ended', 'Bitti');
  String get statusPillNotStarted => _pick('NOT STARTED', 'BAŞLAMADI');
  String get statusPillActive => _pick('ACTIVE', 'AKTİF');
  String get statusPillEnded => _pick('ENDED', 'BİTTİ');

  // Home screen
  String get createManageSessionButton =>
      _pick('CREATE / MANAGE A SESSION', 'OTURUM OLUŞTUR / YÖNET');
  String get joinAsInterpreterButton =>
      _pick('JOIN AS INTERPRETER', 'ÇEVİRMEN OLARAK KATIL');

  // Session list screen
  String get yourSessionsTitle => _pick('Your sessions', 'Oturumların');
  String get noSessionsYet => _pick(
      'No sessions yet. Create one to get started.',
      'Henüz oturum yok. Başlamak için bir tane oluştur.');
  String get newSessionButton => _pick('NEW SESSION', 'YENİ OTURUM');
  String sessionCodeSubtitle(String code, String status) =>
      _pick('Code $code · $status', 'Kod $code · $status');

  // Session dashboard screen
  String get sessionScreenTitle => _pick('Session', 'Oturum');
  String chatTitle(String sessionName) =>
      _pick('Chat - $sessionName', 'Sohbet - $sessionName');
  String get sourceLanguageLabel => _pick('Source language', 'Kaynak dil');
  String get startStopSessionLabel =>
      _pick('Start / stop session', 'Oturumu başlat / durdur');
  String get endSessionButton => _pick('END SESSION', 'OTURUMU BİTİR');
  String get listenerCodeLabel => _pick('LISTENER CODE', 'DİNLEYİCİ KODU');
  String get listenerCodeDescription => _pick(
      'One code for all languages, share with listeners.',
      'Tüm diller için tek kod, dinleyicilerle paylaş.');
  String get interpreterChannelCodesHeader =>
      _pick('INTERPRETER CHANNEL CODES', 'ÇEVİRMEN KANAL KODLARI');
  String get copyTooltip => _pick('Copy', 'Kopyala');
  String channelCodeLabel(String language) =>
      _pick('$language CHANNEL CODE', '$language KANAL KODU');
  String channelCodeDescription(String language) => _pick(
      'Interpreters translating into $language join with this code.',
      '$language diline çeviri yapan çevirmenler bu kodla katılır.');

  // Create-session screen
  String get newSessionTitle => _pick('New session', 'Yeni oturum');
  String get sessionNameLabel => _pick('Session name', 'Oturum adı');
  String get sessionNameRequired =>
      _pick('Session name is required', 'Oturum adı gerekli');
  String get descriptionOptionalLabel =>
      _pick('Description (optional)', 'Açıklama (opsiyonel)');
  String get targetLanguagesLabel => _pick('Target languages', 'Hedef diller');
  String get searchLanguageHint => _pick('Search language', 'Dil ara');
  String get pickSourceLanguageError =>
      _pick('Pick a source language.', 'Bir kaynak dil seç.');
  String get pickTargetLanguageError =>
      _pick('Pick at least one target language.', 'En az bir hedef dil seç.');
  String get createSessionButton => _pick('CREATE SESSION', 'OTURUM OLUŞTUR');
  String selectedCount(int count) => _pick('$count selected', '$count seçildi');
  String get okButton => _pick('OK', 'TAMAM');
}
