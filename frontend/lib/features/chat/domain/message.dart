enum SenderKind { guide, interpreter }

SenderKind senderKindFromJson(String value) {
  switch (value) {
    case 'guide':
      return SenderKind.guide;
    case 'interpreter':
      return SenderKind.interpreter;
    default:
      throw ArgumentError('Unknown sender_kind: $value');
  }
}

/// One chat message (see MessageSerializer). `channelId` is null for a
/// general message (guide + every interpreter in the session) or set
/// for one scoped to a single channel - see ChatTarget.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.senderKind,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final int? channelId;
  final SenderKind senderKind;
  final int? senderId;
  final String? senderName;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        channelId: json['channel'] as int?,
        senderKind: senderKindFromJson(json['sender_kind'] as String),
        senderId: json['sender'] as int?,
        senderName: json['sender_name'] as String?,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
