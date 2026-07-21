enum SenderKind { guide, interpreter, listener }

SenderKind senderKindFromJson(String value) {
  switch (value) {
    case 'guide':
      return SenderKind.guide;
    case 'interpreter':
      return SenderKind.interpreter;
    case 'listener':
      return SenderKind.listener;
    default:
      throw ArgumentError('Unknown sender_kind: $value');
  }
}

/// One chat message (see MessageSerializer). `senderName` is the
/// Guide/Interpreter's registered display name - null for listener
/// senders, who have no account (see ChatMessage's sender_kind).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderKind,
    required this.senderId,
    required this.senderName,
    required this.senderListenerUuid,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final SenderKind senderKind;
  final int? senderId;
  final String? senderName;
  final String? senderListenerUuid;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        senderKind: senderKindFromJson(json['sender_kind'] as String),
        senderId: json['sender'] as int?,
        senderName: json['sender_name'] as String?,
        senderListenerUuid: json['sender_listener_uuid'] as String?,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
