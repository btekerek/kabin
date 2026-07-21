import '../../../core/agora/agora_join_result.dart';

/// Carried via go_router's `extra` from the join screen to the
/// listening screen - avoids re-fetching anything the join call
/// already returned. [channelId]/[listenerUuid] are what
/// ListenerStatusSocket needs to learn about session status changes.
class ListeningArgs {
  const ListeningArgs({
    required this.joinResult,
    required this.channelId,
    required this.channelLanguage,
    required this.sessionName,
    required this.listenerUuid,
  });

  final AgoraJoinResult joinResult;
  final int channelId;
  final String channelLanguage;
  final String sessionName;
  final String listenerUuid;
}
