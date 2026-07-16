import '../../../core/agora/agora_join_result.dart';

/// Carried via go_router's `extra` from the join screen to the
/// listening screen - avoids re-fetching anything the join call
/// already returned.
class ListeningArgs {
  const ListeningArgs({
    required this.joinResult,
    required this.channelLanguage,
    required this.sessionName,
  });

  final AgoraJoinResult joinResult;
  final String channelLanguage;
  final String sessionName;
}
