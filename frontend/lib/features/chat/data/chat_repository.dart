import 'package:dio/dio.dart';

import '../domain/message.dart';

/// Wraps MessageListCreateView - one REST endpoint shared by all three
/// roles (see IsSessionParticipant on the backend). `listenerUuid` is
/// only sent for anonymous listener senders; guide/interpreter identify
/// themselves via the shared Dio instance's Authorization header (see
/// DioClientFactory) - and for a logged-out listener that header is
/// simply absent, which is exactly what the backend expects.
class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  /// Returns the most recent [limit] messages, chronological ascending,
  /// or (with [beforeId]) the [limit] messages immediately before that
  /// one - see MessageListCreateView.get(). Without [beforeId] this is
  /// always "the current tail," not a page number, so repeatedly
  /// calling it with no arguments stays correct even as new messages
  /// arrive - only [beforeId] pages backward in time.
  Future<List<ChatMessage>> history(
    int sessionId, {
    int? beforeId,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/api/sessions/$sessionId/messages/',
      queryParameters: {
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      },
    );
    return (response.data as List)
        .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> send({
    required int sessionId,
    required String body,
    String? listenerUuid,
  }) async {
    final response =
        await _dio.post('/api/sessions/$sessionId/messages/', data: {
      'body': body,
      if (listenerUuid != null) 'listener_uuid': listenerUuid,
    });
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }
}
