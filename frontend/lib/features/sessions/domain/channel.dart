/// A single language channel within a session. `interpreterCode` is only
/// ever present for the Guide's own view and the Interpreter's own join
/// response (both use ChannelSerializer) - the listener-facing shape
/// (ListenerChannelSerializer) omits it and is modeled separately as
/// ListenerChannel. `sessionId` exists so an Interpreter - who only ever
/// identifies a channel by its join code, never the session it belongs
/// to (see ADR-003) - has a session id to reach session-scoped features
/// like chat.
class Channel {
  const Channel({
    required this.id,
    required this.sessionId,
    required this.language,
    required this.interpreterCode,
    required this.isSource,
  });

  final int id;
  final int sessionId;
  final String language;
  final String interpreterCode;
  final bool isSource;

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as int,
        sessionId: json['session'] as int,
        language: json['language'] as String,
        interpreterCode: json['interpreter_code'] as String,
        isSource: json['is_source'] as bool,
      );
}
