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

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      ref.read(authSessionProvider).updateTokens(tokens);
      return ref.read(authRepositoryProvider).me();
    });
  }

  /// role is 'guide' or 'interpreter', picked by the user on the
  /// register screen - the backend and router both already handle
  /// either account type end to end (see RegisterSerializer,
  /// IsGuide/IsInterpreter, and app_router.dart's redirect logic).
  Future<void> register({
    required String email,
    required String password,
    required String role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.register(email: email, password: password, role: role);
      final tokens = await repository.login(email: email, password: password);
      ref.read(authSessionProvider).updateTokens(tokens);
      return repository.me();
    });
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
