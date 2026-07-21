/// Carried via go_router's `extra` into ChatScreen. [channelId] is only
/// set for an interpreter (their claimed channel) - a guide only ever
/// has the general (session-wide) scope, so ChatScreen shows a
/// General/Channel tab switcher only when it's present.
class ChatArgs {
  const ChatArgs({
    required this.sessionId,
    this.channelId,
    required this.accessToken,
    required this.title,
  });

  final int sessionId;
  final int? channelId;
  final String accessToken;
  final String title;
}
