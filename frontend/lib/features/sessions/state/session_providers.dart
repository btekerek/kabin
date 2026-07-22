import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../data/session_repository.dart';
import '../domain/language.dart';
import '../domain/session.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(dioProvider));
});

/// The full language registry - fetched once and reused everywhere a
/// language picker is needed. `keepAlive` isn't set explicitly; this is
/// a plain FutureProvider so Riverpod's default (kept alive as long as
/// something's watching it, which in practice is "the whole time the
/// create-session screen is open") is exactly right here.
final languagesProvider = FutureProvider<List<Language>>((ref) {
  return ref.watch(sessionRepositoryProvider).languages();
});

/// code -> full name lookup derived from [languagesProvider], for
/// screens that show a language's full name alongside its bare code
/// (see LanguageLabel) - e.g. channel.language/session.sourceLanguage
/// are always just a code like "TR", not enough on its own for someone
/// unfamiliar with ISO codes to recognize. Empty until the registry
/// resolves; LanguageLabel falls back to the bare code until then
/// rather than blocking on the fetch.
final languageNamesProvider = Provider<Map<String, String>>((ref) {
  final languages = ref.watch(languagesProvider).valueOrNull ?? const [];
  return {for (final language in languages) language.code: language.name};
});

/// The signed-in guide's own sessions (see SessionListCreateView's
/// get_queryset - the backend already scopes this to request.user, so
/// there's no client-side filtering to do here).
final sessionListProvider =
    AsyncNotifierProvider<SessionListController, List<Session>>(
  SessionListController.new,
);

class SessionListController extends AsyncNotifier<List<Session>> {
  @override
  FutureOr<List<Session>> build() {
    return ref.read(sessionRepositoryProvider).listSessions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(sessionRepositoryProvider).listSessions());
  }
}

/// A single session's live detail, keyed by id - the dashboard screen's
/// source of truth. start()/stop()/end() re-fetch the transitioned
/// session from the response body rather than trusting a locally
/// mutated copy, since the backend is the only source of truth for
/// which transitions are legal (Session.can_transition_to).
final sessionDetailProvider =
    AsyncNotifierProvider.family<SessionDetailController, Session, int>(
  SessionDetailController.new,
);

class SessionDetailController extends FamilyAsyncNotifier<Session, int> {
  @override
  FutureOr<Session> build(int arg) {
    return ref.read(sessionRepositoryProvider).getSession(arg);
  }

  Future<void> start() => _transition((repo) => repo.start(arg));
  Future<void> stop() => _transition((repo) => repo.stop(arg));
  Future<void> end() => _transition((repo) => repo.end(arg));

  Future<void> _transition(
      Future<Session> Function(SessionRepository) action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => action(ref.read(sessionRepositoryProvider)));
  }
}
