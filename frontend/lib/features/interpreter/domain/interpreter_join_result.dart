import '../../../core/agora/agora_join_result.dart';
import '../../sessions/domain/channel.dart';

/// ChannelJoinView returns the same {agora_app_id, ...} credential shape
/// as the listener join, plus a `channel` object serialized with
/// ChannelSerializer (unlike the listener's ListenerChannelSerializer,
/// this one includes interpreter_code) - see apps/sessions/views.py.
///
/// `source` is a second, audience-role set of join credentials for the
/// session's source channel (the Guide's own mic) - this is what lets
/// BroadcastingScreen open a second connection to actually hear what's
/// being interpreted, alongside broadcasting the translation on
/// [joinResult]/[channel]. It's null when the claimed channel *is* the
/// source channel itself (nothing to relay to it).
class InterpreterJoinResult {
  const InterpreterJoinResult({
    required this.joinResult,
    required this.channel,
    required this.source,
    required this.sourceLanguage,
  });

  final AgoraJoinResult joinResult;
  final Channel channel;
  final AgoraJoinResult? source;
  final String? sourceLanguage;
}
