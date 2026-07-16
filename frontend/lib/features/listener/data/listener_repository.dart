import 'package:dio/dio.dart';

import '../../../core/agora/agora_join_result.dart';
import '../domain/listener_session_summary.dart';

class ListenerRepository {
  ListenerRepository(this._dio);

  final Dio _dio;

  /// PIN -> session summary + channel list. Public, unauthenticated,
  /// rate-limited server-side (see ADR-002's session-lookup throttle) -
  /// nothing extra to handle here, a 429 surfaces as a normal
  /// {code, message} error like any other.
  Future<ListenerSessionSummary> lookup(String listenerCode) async {
    final response = await _dio.post('/api/sessions/lookup/', data: {
      'listener_code': listenerCode,
    });
    return ListenerSessionSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Joins a specific channel within [sessionId] as [listenerUuid].
  /// Rejoining with the same listenerUuid switches channel rather than
  /// spending a second seat against the listener cap (see
  /// SessionJoinView) - this method doesn't need to know which case it
  /// is, the backend handles both identically from the caller's view.
  Future<AgoraJoinResult> join({
    required int sessionId,
    required String listenerUuid,
    required int channelId,
  }) async {
    final response = await _dio.post('/api/sessions/$sessionId/join/', data: {
      'listener_uuid': listenerUuid,
      'channel_id': channelId,
    });
    return AgoraJoinResult.fromJson(response.data as Map<String, dynamic>);
  }
}
