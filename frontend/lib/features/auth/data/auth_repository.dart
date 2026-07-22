import 'package:dio/dio.dart';

import '../../../core/auth/token_pair.dart';
import '../domain/user.dart';

/// Thin wrapper over /api/auth/* - no state, no caching, just typed
/// request/response shapes. AuthController (state/auth_providers.dart)
/// owns what happens with the results.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// Creates the account but does NOT log it in - the account is
  /// inactive until the code emailed here is confirmed via verifyEmail
  /// (see RegisterSerializer.create/VerifyEmailView).
  Future<User> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _dio.post('/api/auth/register/', data: {
      'email': email,
      'password': password,
      'username': username,
    });
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// Confirms the code and activates the account - returns a token pair
  /// directly (like login) so the caller doesn't need a second /login/
  /// call right after.
  Future<TokenPair> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _dio.post('/api/auth/verify-email/', data: {
      'email': email,
      'code': code,
    });
    final data = response.data as Map<String, dynamic>;
    return TokenPair(
        access: data['access'] as String, refresh: data['refresh'] as String);
  }

  /// A no-op server-side for an unknown or already-verified email - safe
  /// to call without checking state first (see ResendVerificationView).
  Future<void> resendVerification(String email) async {
    await _dio.post('/api/auth/resend-verification/', data: {
      'email': email,
    });
  }

  /// [identifier] is either the account's email or username - see
  /// LoginSerializer, which accepts either interchangeably.
  Future<TokenPair> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post('/api/auth/login/', data: {
      'identifier': identifier,
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    return TokenPair(
        access: data['access'] as String, refresh: data['refresh'] as String);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/api/auth/logout/', data: {'refresh': refreshToken});
  }

  Future<User> me() async {
    final response = await _dio.get('/api/auth/me/');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> updateUsername(String username) async {
    final response = await _dio.patch('/api/auth/me/', data: {
      'username': username,
    });
    return User.fromJson(response.data as Map<String, dynamic>);
  }
}
