import 'package:dio/dio.dart';

import '../../../core/agora/agora_join_result.dart';
import '../../sessions/domain/channel.dart';
import '../domain/interpreter_join_result.dart';

/// Authenticated (Interpreter role) counterpart to ListenerRepository -
/// wraps ChannelJoinView/ChannelLeaveView. Unlike the listener flow,
/// there's no separate lookup step: the interpreter code alone
/// identifies the channel to claim (see ADR-003).
class InterpreterRepository {
  InterpreterRepository(this._dio);

  final Dio _dio;

  Future<InterpreterJoinResult> join(String interpreterCode) async {
    final response = await _dio.post('/api/channels/join/', data: {
      'interpreter_code': interpreterCode,
    });
    final data = response.data as Map<String, dynamic>;
    return InterpreterJoinResult(
      joinResult: AgoraJoinResult.fromJson(data),
      channel: Channel.fromJson(data['channel'] as Map<String, dynamic>),
    );
  }

  /// A no-op server-side if the caller doesn't hold the channel - safe
  /// to call defensively (e.g. from a screen's dispose) without first
  /// checking whether the claim is actually ours.
  Future<void> leave(String interpreterCode) async {
    await _dio.post('/api/channels/leave/', data: {
      'interpreter_code': interpreterCode,
    });
  }
}
