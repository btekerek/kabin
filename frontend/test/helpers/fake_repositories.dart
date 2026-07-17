import 'dart:async';

import 'package:dio/dio.dart';
import 'package:kabin/core/auth/token_pair.dart';
import 'package:kabin/features/auth/data/auth_repository.dart';
import 'package:kabin/features/auth/domain/user.dart';
import 'package:kabin/features/chat/data/chat_repository.dart';
import 'package:kabin/features/chat/domain/message.dart';
import 'package:kabin/features/sessions/data/session_repository.dart';
import 'package:kabin/features/sessions/domain/language.dart';
import 'package:kabin/features/sessions/domain/session.dart';

/// A DioException with no real request behind it - just enough shape
/// for code that pattern-matches on `is DioException` (AuthController's
/// bootstrap, apiErrorMessage) to behave the same as it would against a
/// real failed request.
DioException fakeDioException(
    {String path = '/fake/', Map<String, dynamic>? data}) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    response: data == null
        ? null
        : Response(requestOptions: requestOptions, data: data, statusCode: 400),
  );
}

/// Overrides every AuthRepository method so tests can script exact
/// responses/failures without a real backend. The super() Dio is never
/// used - all methods below are overridden.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(Dio());

  User? userToReturn;
  Object? meError;
  TokenPair? loginTokens;
  Object? loginError;
  bool registerCalled = false;
  bool logoutCalled = false;

  @override
  Future<User> me() async {
    if (meError != null) throw meError!;
    final user = userToReturn;
    if (user == null) throw fakeDioException();
    return user;
  }

  @override
  Future<TokenPair> login(
      {required String email, required String password}) async {
    if (loginError != null) throw loginError!;
    return loginTokens!;
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String role,
  }) async {
    registerCalled = true;
    return userToReturn!;
  }

  @override
  Future<void> logout(String refreshToken) async {
    logoutCalled = true;
  }
}

class FakeSessionRepository extends SessionRepository {
  FakeSessionRepository() : super(Dio());

  List<Session> sessionsToReturn = [];
  Session? sessionToReturn;
  List<Language> languagesToReturn = [];
  Object? nextError;

  final List<String> calledActions = [];

  @override
  Future<List<Session>> listSessions() async {
    calledActions.add('list');
    return sessionsToReturn;
  }

  @override
  Future<Session> createSession({
    required String name,
    required String sourceLanguage,
    required List<String> targetLanguages,
  }) async {
    calledActions.add('create');
    return sessionToReturn!;
  }

  @override
  Future<Session> getSession(int id) async {
    calledActions.add('get:$id');
    return sessionToReturn!;
  }

  @override
  Future<Session> start(int id) => _transition('start', id);

  @override
  Future<Session> stop(int id) => _transition('stop', id);

  @override
  Future<Session> end(int id) => _transition('end', id);

  Future<Session> _transition(String action, int id) async {
    calledActions.add('$action:$id');
    if (nextError != null) {
      final error = nextError!;
      nextError = null;
      throw error;
    }
    return sessionToReturn!;
  }

  @override
  Future<List<Language>> languages() async {
    calledActions.add('languages');
    return languagesToReturn;
  }
}

/// [sendCompleter], when set, lets a test control exactly when a `send`
/// call resolves - needed to observe the pending-message state that
/// exists between `send()` being called and it settling.
class FakeChatRepository extends ChatRepository {
  FakeChatRepository() : super(Dio());

  List<ChatMessage> historyToReturn = [];
  ChatMessage? messageToReturn;
  Object? nextSendError;
  Completer<ChatMessage>? sendCompleter;

  final List<String> sentBodies = [];

  @override
  Future<List<ChatMessage>> history(
    int sessionId, {
    int? beforeId,
    int limit = 50,
  }) async =>
      historyToReturn;

  @override
  Future<ChatMessage> send({
    required int sessionId,
    required String body,
    String? listenerUuid,
  }) {
    sentBodies.add(body);
    if (sendCompleter != null) return sendCompleter!.future;
    if (nextSendError != null) {
      final error = nextSendError!;
      nextSendError = null;
      return Future.error(error);
    }
    return Future.value(messageToReturn!);
  }
}
