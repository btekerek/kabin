/// Which of the two chat scopes a screen/controller/socket is talking
/// to - general (guide + every interpreter in the session) or one
/// channel (only the interpreter(s) holding a claim on it). See the
/// backend's Message model for the same distinction.
class ChatTarget {
  const ChatTarget.general(this.sessionId) : channelId = null;

  const ChatTarget.channel(this.channelId) : sessionId = null;

  final int? sessionId;
  final int? channelId;

  String get restPath => channelId != null
      ? '/api/channels/$channelId/messages/'
      : '/api/sessions/$sessionId/messages/';

  String get wsPath => channelId != null
      ? '/ws/channels/$channelId/chat/'
      : '/ws/sessions/$sessionId/chat/';
}
