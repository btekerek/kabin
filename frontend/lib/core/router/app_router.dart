import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/state/auth_providers.dart';
import '../../features/chat/presentation/chat_args.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/interpreter/presentation/broadcasting_args.dart';
import '../../features/interpreter/presentation/broadcasting_screen.dart';
import '../../features/interpreter/presentation/interpreter_join_screen.dart';
import '../../features/listener/presentation/listener_join_screen.dart';
import '../../features/listener/presentation/listening_args.dart';
import '../../features/listener/presentation/listening_screen.dart';
import '../../features/sessions/presentation/create_session_screen.dart';
import '../../features/sessions/presentation/session_dashboard_screen.dart';
import '../../features/sessions/presentation/session_list_screen.dart';
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
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final onSplash = state.matchedLocation == '/splash';
      final bypassesAuthGate = state.matchedLocation == '/join' ||
          state.matchedLocation == '/listen' ||
          state.matchedLocation == '/chat';
      if (bypassesAuthGate) return null;

      // No account role to branch on (see features/auth/domain/user.dart) -
      // every logged-in user lands on the same Home screen and picks
      // "create a session" or "join as interpreter" from there.
      return authState.when(
        loading: () => onSplash ? null : '/splash',
        error: (_, __) => loggingIn ? null : '/login',
        data: (user) {
          if (user == null) {
            return loggingIn ? null : '/login';
          }
          return (loggingIn || onSplash) ? '/home' : null;
        },
      );
    },
    routes: [
      GoRoute(
          path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
          path: '/join',
          builder: (context, state) => const ListenerJoinScreen()),
      GoRoute(
        path: '/listen',
        builder: (context, state) =>
            ListeningScreen(args: state.extra! as ListeningArgs),
      ),
      GoRoute(
        path: '/interpret',
        builder: (context, state) => const InterpreterJoinScreen(),
      ),
      GoRoute(
        path: '/broadcast',
        builder: (context, state) =>
            BroadcastingScreen(args: state.extra! as BroadcastingArgs),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => ChatScreen(args: state.extra! as ChatArgs),
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
