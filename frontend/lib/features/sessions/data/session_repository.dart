import 'package:dio/dio.dart';

import '../../../core/agora/agora_join_result.dart';
import '../domain/language.dart';
import '../domain/session.dart';

class SessionRepository {
  SessionRepository(this._dio);

  final Dio _dio;

  /// Publisher token for the session's own source channel - this is
  /// what makes the Guide's live mic reach interpreters and any
  /// listener who picks "original audio" (see SessionBroadcastView).
  /// Deliberately separate from start()/stop()/end(): mic on/off is
  /// independent of session status.
  Future<AgoraJoinResult> broadcast(int id) async {
    final response = await _dio.post('/api/sessions/$id/broadcast/');
    return AgoraJoinResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Session>> listSessions() async {
    final response = await _dio.get('/api/sessions/');
    return (response.data as List<dynamic>)
        .map((entry) => Session.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<Session> createSession({
    required String name,
    required String sourceLanguage,
    required List<String> targetLanguages,
  }) async {
    final response = await _dio.post('/api/sessions/', data: {
      'name': name,
      'source_language': sourceLanguage,
      'target_languages': targetLanguages,
    });
    return Session.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Session> getSession(int id) async {
    final response = await _dio.get('/api/sessions/$id/');
    return Session.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Session> start(int id) => _transition(id, 'start');
  Future<Session> stop(int id) => _transition(id, 'stop');
  Future<Session> end(int id) => _transition(id, 'end');

  Future<Session> _transition(int id, String action) async {
    final response = await _dio.post('/api/sessions/$id/$action/');
    return Session.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Language>> languages() async {
    final response = await _dio.get('/api/languages/');
    return (response.data as List<dynamic>)
        .map((entry) => Language.fromJson(entry as Map<String, dynamic>))
        .toList();
  }
}
