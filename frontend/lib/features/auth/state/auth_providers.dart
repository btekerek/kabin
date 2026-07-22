import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/dio_client.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// One [AuthSession] for the app's lifetime - holds the in-memory access
/// token and owns the "refresh token just died" stream that
/// [AuthController] listens to.
final authSessionProvider = Provider<AuthSession>((ref) {
  final session = AuthSession();
  ref.onDispose(session.dispose);
  return session;
});

/// One shared [Dio] instance, wired with the token-refresh interceptor
/// (see ADR-001 / DioClientFactory). Every repository in the app should
/// go through this rather than constructing its own Dio.
final dioProvider = Provider<Dio>((ref) {
  final authSession = ref.watch(authSessionProvider);
  return DioClientFactory(authSession: authSession).create();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

/// The current account, or `null` if logged out. This is the one thing
/// the router and every screen check to know "am I logged in, and as
/// who" - see ADR-007.
final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<User?> {
  @override
  FutureOr<User?> build() {
    // If the refresh token itself ever turns out to be dead (a real
    // logout triggered from deep inside DioClientFactory's 401 handling,
    // not something this controller initiated), fall back to logged-out
    // state so the router sends the user back to /login.
    final subscription = ref.watch(authSessionProvider).onLoggedOut.listen((_) {
      state = const AsyncData(null);
    });
    ref.onDispose(subscription.cancel);

    return _bootstrap();
  }

  /// On app start there's no in-memory access token yet, only whatever
  /// refresh token TokenStorage has persisted (if any). Deliberately
  /// doesn't pre-emptively call the refresh endpoint here - calling
  /// /api/auth/me/ with no access token attached triggers exactly the
  /// same 401 -> refresh -> retry path DioClientFactory already handles
  /// for every other request, so there's nothing bespoke to write. If
  /// there's no refresh token either, that same path fails harmlessly
  /// and this just returns null (logged out).
  Future<User?> _bootstrap() async {
    try {
      return await ref.read(authRepositoryProvider).me();
    } on DioException {
      return null;
    }
  }

  /// [identifier] is either the account's email or username.
  Future<void> login(
      {required String identifier, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authRepositoryProvider).login(
            identifier: identifier,
            password: password,
          );
      ref.read(authSessionProvider).updateTokens(tokens);
      return ref.read(authRepositoryProvider).me();
    });
  }

  /// There's no role to pick at registration - see HomeScreen for how
  /// an account becomes a "guide" (creates a session) or "interpreter"
  /// (claims a channel) per action instead.
  ///
  /// Doesn't log the account in - it's inactive until verifyEmail
  /// succeeds (see RegisterView) - so like updateUsername, this throws
  /// on failure rather than going through AsyncValue.guard: the shared
  /// logged-in/out state shouldn't move either way over a registration
  /// attempt, since the account isn't usable yet regardless of outcome.
  /// RegisterScreen shows its own local busy/error state around this.
  Future<void> register({
    required String email,
    required String password,
    required String username,
  }) {
    return ref.read(authRepositoryProvider).register(
          email: email,
          password: password,
          username: username,
        );
  }

  /// Confirms the emailed code and logs the now-active account in
  /// directly - verifyEmail's response is a token pair, exactly like
  /// login's, so this mirrors login() rather than register().
  Future<void> verifyEmail(
      {required String email, required String code}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref
          .read(authRepositoryProvider)
          .verifyEmail(email: email, code: code);
      ref.read(authSessionProvider).updateTokens(tokens);
      return ref.read(authRepositoryProvider).me();
    });
  }

  /// Fire-and-forget "send me another code" - throws on failure like
  /// register()/updateUsername() so VerifyEmailScreen can show it
  /// locally without disturbing the shared logged-out state.
  Future<void> resendVerification(String email) {
    return ref.read(authRepositoryProvider).resendVerification(email);
  }

  /// Fire-and-forget "send me a reset code" - throws on failure like
  /// resendVerification() so ForgotPasswordScreen can show it locally
  /// without disturbing the shared logged-out state.
  Future<void> requestPasswordReset(String email) {
    return ref.read(authRepositoryProvider).requestPasswordReset(email);
  }

  /// Confirms the emailed code and logs the account in directly -
  /// confirmPasswordReset's response is a token pair, exactly like
  /// verifyEmail's, so this mirrors verifyEmail() rather than register().
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final tokens =
          await ref.read(authRepositoryProvider).confirmPasswordReset(
                email: email,
                code: code,
                newPassword: newPassword,
              );
      ref.read(authSessionProvider).updateTokens(tokens);
      return ref.read(authRepositoryProvider).me();
    });
  }

  /// Throws on failure (e.g. USERNAME_IN_USE) rather than going through
  /// AsyncValue.guard like login/register - the caller (ProfileScreen)
  /// shows that error locally, and the shared auth state shouldn't flip
  /// to AsyncError over a rejected edit while already logged in.
  Future<void> updateUsername(String username) async {
    final updated =
        await ref.read(authRepositoryProvider).updateUsername(username);
    state = AsyncData(updated);
  }

  Future<void> logout() async {
    final authSession = ref.read(authSessionProvider);
    final refreshToken = await authSession.refreshToken;
    if (refreshToken != null) {
      try {
        await ref.read(authRepositoryProvider).logout(refreshToken);
      } on DioException {
        // Best-effort server-side blacklist; local logout proceeds
        // either way, matching the backend's own "already invalid is
        // still a successful logout" behavior (see LogoutView).
      }
    }
    await authSession.clear();
    state = const AsyncData(null);
  }
}
