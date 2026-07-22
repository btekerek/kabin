import '../../../core/agora/agora_join_result.dart';
import '../domain/listener_channel.dart';

/// Carried via go_router's `extra` from the join screen to the
/// listening screen - avoids re-fetching anything the join call
/// already returned. [channelId]/[listenerUuid] are what
/// ListenerStatusSocket needs to learn about session status changes.
/// [sessionId]/[channels] are what the listening screen's language
/// dropdown needs to switch channels without navigating back to the
/// join screen.
class ListeningArgs {
  const ListeningArgs({
    required this.joinResult,
    required this.sessionId,
    required this.channelId,
    required this.channels,
    required this.sessionName,
    required this.listenerUuid,
  });

  final AgoraJoinResult joinResult;
  final int sessionId;
  final int channelId;
  final List<ListenerChannel> channels;
  final String sessionName;
  final String listenerUuid;
}
