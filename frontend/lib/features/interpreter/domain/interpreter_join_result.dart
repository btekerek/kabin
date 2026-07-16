import '../../../core/agora/agora_join_result.dart';
import '../../sessions/domain/channel.dart';

/// ChannelJoinView returns the same {agora_app_id, ...} credential shape
/// as the listener join, plus a `channel` object serialized with
/// ChannelSerializer (unlike the listener's ListenerChannelSerializer,
/// this one includes interpreter_code) - see apps/sessions/views.py.
class InterpreterJoinResult {
  const InterpreterJoinResult({
    required this.joinResult,
    required this.channel,
  });

  final AgoraJoinResult joinResult;
  final Channel channel;
}
