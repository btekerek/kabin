import 'package:dio/dio.dart';

import '../domain/chat_target.dart';
import '../domain/message.dart';

/// Wraps MessageListCreateView/ChannelMessageListCreateView - one REST
/// shape shared by both chat scopes (see ChatTarget). Guide/interpreter
/// identify themselves via the shared Dio instance's Authorization
/// header (see DioClientFactory); there is no anonymous sender anymore.
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
    ChatTarget target, {
    int? beforeId,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      target.restPath,
      queryParameters: {
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      },
    );
    return (response.data as List)
        .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> send(
      {required ChatTarget target, required String body}) async {
    final response = await _dio.post(target.restPath, data: {'body': body});
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }
}
