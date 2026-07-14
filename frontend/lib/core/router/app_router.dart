import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/state/auth_providers.dart';
import '../../features/sessions/presentation/create_session_screen.dart';
import '../../features/sessions/presentation/session_dashboard_screen.dart';
import '../../features/sessions/presentation/session_list_screen.dart';
import 'role_not_supported_screen.dart';
import 'splash_screen.dart';

/// A plain Provider that watches authControllerProvider and rebuilds
/// the whole GoRouter on auth state changes (login/logout/bootstrap
/// resolving) - see ADR-007 for why this simpler approach was chosen
/// over a GoRouterRefreshStream bridge.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loggingIn =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final onSplash = state.matchedLocation == '/splash';

      return authState.when(
        loading: () => onSplash ? null : '/splash',
        error: (_, __) => loggingIn ? null : '/login',
        data: (user) {
          if (user == null) {
            return loggingIn ? null : '/login';
          }
          if (!user.isGuide) {
            return state.matchedLocation == '/unsupported-role' ? null : '/unsupported-role';
          }
          if (loggingIn || onSplash) {
            return '/sessions';
          }
          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/unsupported-role',
        builder: (context, state) => const RoleNotSupportedScreen(),
      ),
      GoRoute(
        path: '/sessions',
        builder: (context, state) => const SessionListScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateSessionScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => SessionDashboardScreen(
              sessionId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
});
