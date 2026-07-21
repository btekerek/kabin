import 'package:dio/dio.dart';

import '../../../core/auth/token_pair.dart';
import '../domain/user.dart';

/// Thin wrapper over /api/auth/* - no state, no caching, just typed
/// request/response shapes. AuthController (state/auth_providers.dart)
/// owns what happens with the results.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

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
