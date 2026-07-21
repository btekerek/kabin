import '../../../core/agora/agora_join_result.dart';
import '../../listener/domain/listener_channel.dart';
import '../../sessions/domain/channel.dart';

/// One relay connection's worth of join credentials plus which channel
/// they're for - the same shape ChannelJoinView's `relay` key and
/// ChannelRelayView both return (see apps/sessions/views.py's
/// _relay_payload).
class RelayJoinResult {
  const RelayJoinResult({required this.joinResult, required this.channel});

  final AgoraJoinResult joinResult;
  final ListenerChannel channel;

  factory RelayJoinResult.fromJson(Map<String, dynamic> json) =>
      RelayJoinResult(
        joinResult: AgoraJoinResult.fromJson(json),
        channel:
            ListenerChannel.fromJson(json['channel'] as Map<String, dynamic>),
      );
}

/// ChannelJoinView/ChannelSwitchView both return the same
/// {agora_app_id, ...} credential shape as the listener join, plus a
/// `channel` object serialized with ChannelSerializer (unlike the
/// listener's ListenerChannelSerializer, this one includes
/// interpreter_code) - see apps/sessions/views.py's _claim_payload.
///
/// `relay` is a second, audience-role set of join credentials for
/// whichever channel this interpreter is relaying from (their "source
/// language" dropdown) while they interpret - the session's original
/// source by default, but see [availableRelayChannels]/ChannelRelayView
/// for switching to a different one. It's null when the claimed channel
/// *is* the source channel itself (nothing to relay from).
///
/// [availableTargetChannels] backs the "target language" dropdown - see
/// ChannelSwitchView for moving the claim itself to a different channel.
class InterpreterJoinResult {
  const InterpreterJoinResult({
    required this.joinResult,
    required this.channel,
    required this.relay,
    required this.availableRelayChannels,
    required this.availableTargetChannels,
  });

  final AgoraJoinResult joinResult;
  final Channel channel;
  final RelayJoinResult? relay;
  final List<ListenerChannel> availableRelayChannels;
  final List<ListenerChannel> availableTargetChannels;
}
