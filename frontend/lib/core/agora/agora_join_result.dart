/// The credentials returned by either join endpoint - listener
/// (SessionJoinView) or interpreter (ChannelJoinView) - see
/// apps/sessions/views.py. Both return the identical
/// {agora_app_id, agora_channel_name, agora_token, expires_in, channel}
/// shape; this model captures the join-credential part that's common to
/// both, leaving the nested `channel` object (whose fields differ
/// slightly between the two - ListenerChannelSerializer omits
/// interpreter_code) to whichever repository parsed the response.
class AgoraJoinResult {
  const AgoraJoinResult({
    required this.agoraAppId,
    required this.agoraChannelName,
    required this.agoraToken,
    required this.expiresIn,
  });

  final String agoraAppId;
  final String agoraChannelName;
  final String agoraToken;
  final int expiresIn;

  factory AgoraJoinResult.fromJson(Map<String, dynamic> json) => AgoraJoinResult(
        agoraAppId: json['agora_app_id'] as String,
        agoraChannelName: json['agora_channel_name'] as String,
        agoraToken: json['agora_token'] as String,
        expiresIn: json['expires_in'] as int,
      );
}
