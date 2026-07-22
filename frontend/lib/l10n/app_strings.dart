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

  // Landing screen (listener-first tabs)
  String get listenTabLabel => _pick('Listen', 'Dinle');
  String get logInTabLabel => _pick('Log in', 'Giriş yap');

  // Forgot/reset password screens
  String get forgotPasswordPrompt =>
      _pick('Forgot password?', 'Şifreni mi unuttun?');
  String get forgotPasswordTitle => _pick('Forgot password', 'Şifremi unuttum');
  String get forgotPasswordInstructions => _pick(
      "Enter your email and we'll send you a code to reset your password.",
      'E-postanı gir, şifreni sıfırlaman için bir kod gönderelim.');
  String get sendResetCodeButton =>
      _pick('SEND RESET CODE', 'SIFIRLAMA KODU GÖNDER');
  String get resetPasswordTitle => _pick('Reset password', 'Şifreni sıfırla');
  String get resetCodeLabel => _pick('Reset code', 'Sıfırlama kodu');
  String get resetPasswordButton => _pick('RESET PASSWORD', 'ŞİFREYİ SIFIRLA');

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

  // Shared across interpreter/listener broadcast+listen screens
  String get cancelButton => _pick('CANCEL', 'İPTAL');
  String get leaveButton => _pick('LEAVE', 'AYRIL');
  String get connectFailedMessage => _pick(
      'Could not connect. Check your connection and try again.',
      'Bağlanılamadı. Bağlantını kontrol edip tekrar dene.');
  String get sessionEndedBannerMessage =>
      _pick('This session has ended.', 'Bu oturum sona erdi.');
  String get connectingLabel => _pick('Connecting...', 'Bağlanıyor...');
  String get connectionFailedLabel =>
      _pick('Connection failed', 'Bağlantı başarısız');
  String get disconnectedLabel => _pick('Disconnected', 'Bağlantı kesildi');

  // Interpreter join screen
  String get joinAsInterpreterTitle =>
      _pick('Join as interpreter', 'Çevirmen olarak katıl');
  String get channelCodeInputLabel => _pick('Channel code', 'Kanal kodu');
  String get joinChannelButton => _pick('JOIN CHANNEL', 'KANALA KATIL');

  // Broadcasting screen
  String get anotherInterpreterLiveTitle =>
      _pick('Another interpreter is live', 'Başka bir çevirmen yayında');
  String get anotherInterpreterLiveMessage => _pick(
      'Someone else is already broadcasting on this channel. Listeners will hear you both at once if you turn your mic on.',
      'Bu kanalda zaten başka biri yayın yapıyor. Mikrofonunu açarsan dinleyiciler ikinizi de aynı anda duyar.');
  String get turnOnAnywayButton => _pick('TURN ON ANYWAY', 'YİNE DE AÇ');
  String switchLanguageError(String message) => _pick(
      'Could not switch language: $message', 'Dil değiştirilemedi: $message');
  String switchRelayError(String message) => _pick(
      'Could not switch relay: $message', 'Kaynak değiştirilemedi: $message');
  String get relayAudioFailedMessage => _pick(
      'Could not hear the relay audio. Check your connection and try again.',
      'Kaynak sesi duyulamadı. Bağlantını kontrol edip tekrar dene.');
  String leaveError(String message) =>
      _pick('Could not leave: $message', 'Ayrılınamadı: $message');
  String get connectedLabel => _pick('Connected', 'Bağlandı');
  String get broadcastingLabel => _pick('Broadcasting', 'Yayında');
  String get sourceDropdownLabel => _pick('Source', 'Kaynak');
  String get targetDropdownLabel => _pick('Target', 'Hedef');
  String get chatLabel => _pick('Chat', 'Sohbet');

  // Listener join + listening screens
  String get joinSessionTitle => _pick('Join a session', 'Bir oturuma katıl');
  String get listenerPinLabel => _pick('Listener PIN', "Dinleyici PIN'i");
  String get findSessionButton => _pick('FIND SESSION', 'OTURUM BUL');
  String get pickLanguageToListenPrompt =>
      _pick('Pick a language to listen in:', 'Dinlemek istediğin dili seç:');
  String get originalStageAudioLabel =>
      _pick('Original (stage) audio', 'Orijinal (sahne) sesi');
  String get listeningInLabel => _pick('Listening in', 'Şu dilde dinliyorsun');
  String get listeningStatusLabel => _pick('Listening', 'Dinleniyor');
  String get sessionEndedStatusLabel =>
      _pick('Session ended', 'Oturum sona erdi');

  // Chat screen + FAB
  String get generalTabLabel => _pick('GENERAL', 'GENEL');
  String get channelTabLabel => _pick('CHANNEL', 'KANAL');
  String get noMessagesYet => _pick('No messages yet', 'Henüz mesaj yok');
  String get messageHint => _pick('Message', 'Mesaj');
  String get connectionLostLabel => _pick('Connection lost', 'Bağlantı koptu');
  String get guideSenderLabel => _pick('GUIDE', 'REHBER');
  String get interpreterSenderLabel => _pick('INTERPRETER', 'ÇEVİRMEN');
  String get sendingLabel => _pick('Sending...', 'Gönderiliyor...');
  String failedToSendMessage(String error) =>
      _pick('Failed to send: $error', 'Gönderilemedi: $error');
  String get retryButton => _pick('RETRY', 'TEKRAR DENE');
  String get dismissButton => _pick('DISMISS', 'KAPAT');
}
