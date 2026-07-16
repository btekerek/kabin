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

/// One chat message (see MessageSerializer). The backend doesn't expose
/// a sender display name yet - only `sender_kind` plus a raw user id or
/// listener uuid - so the UI can only label a message "Guide" /
/// "Interpreter" / "Listener", not by name. Multiple interpreters in one
/// session will all show under the same generic label until the backend
/// adds a display name field.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderKind,
    required this.senderId,
    required this.senderListenerUuid,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final SenderKind senderKind;
  final int? senderId;
  final String? senderListenerUuid;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        senderKind: senderKindFromJson(json['sender_kind'] as String),
        senderId: json['sender'] as int?,
        senderListenerUuid: json['sender_listener_uuid'] as String?,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
