import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../auth/token_pair.dart';
import 'api_config.dart';
import 'single_flight_refresh.dart';

/// Builds the single Dio instance the whole app shares.
///
/// See ADR-001 for the full design rationale; the short version:
///  - every request gets the in-memory access token attached
///  - a 401 triggers exactly one refresh call no matter how many requests
///    failed at once (SingleFlightRefresh dedupes them)
///  - requests that were waiting on the refresh get retried with the new
///    access token once it lands
///  - if the refresh call itself 401s, the refresh token is dead: clear
///    session state and let AuthSession.onLoggedOut route to the login
///    screen
///  - the refresh endpoint itself is never treated as retryable, or a
///    failing refresh would recursively try to refresh itself
class DioClientFactory {
  DioClientFactory({required this.authSession});

  final AuthSession authSession;
  final SingleFlightRefresh<TokenPair> _refreshCoordinator =
      SingleFlightRefresh<TokenPair>();

  Dio create() {
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = authSession.accessToken;
          if (token != null && !_isRefreshCall(options)) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final isRefreshCall = _isRefreshCall(error.requestOptions);

          if (!isUnauthorized || alreadyRetried || isRefreshCall) {
            handler.next(error);
            return;
          }

          try {
            final newTokens = await _refreshCoordinator.run(
              () => _refresh(dio),
            );
            authSession.updateTokens(newTokens);

            final retryOptions = error.requestOptions;
            retryOptions.extra['retried'] = true;
            retryOptions.headers['Authorization'] = 'Bearer ${newTokens.access}';

            final response = await dio.fetch(retryOptions);
            handler.resolve(response);
          } catch (_) {
            // The refresh call itself failed: refresh token is dead, this
            // is a real logout, not a retryable hiccup.
            await authSession.forceLogout();
            handler.next(error);
          }
        },
      ),
    );

    return dio;
  }

  bool _isRefreshCall(RequestOptions options) =>
      options.path.contains('/api/auth/refresh');

  Future<TokenPair> _refresh(Dio dio) async {
    final refreshToken = await authSession.refreshToken;
    if (refreshToken == null) {
      throw StateError('No refresh token available.');
    }
    final response = await dio.post(
      '/api/auth/refresh/',
      data: {'refresh': refreshToken},
    );
    return TokenPair(
      access: response.data['access'] as String,
      refresh: response.data['refresh'] as String,
    );
  }
}
