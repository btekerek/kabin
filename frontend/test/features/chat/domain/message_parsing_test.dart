import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/features/chat/domain/message.dart';

void main() {
  group('senderKindFromJson', () {
    test('parses each backend value', () {
      expect(senderKindFromJson('guide'), SenderKind.guide);
      expect(senderKindFromJson('interpreter'), SenderKind.interpreter);
      expect(senderKindFromJson('listener'), SenderKind.listener);
    });

    test('throws on an unrecognized value', () {
      expect(() => senderKindFromJson('bogus'), throwsArgumentError);
    });
  });

  group('ChatMessage.fromJson', () {
    test('parses a guide-sent message (sender is a user id)', () {
      final message = ChatMessage.fromJson({
        'id': 1,
        'sender_kind': 'guide',
        'sender': 7,
        'sender_listener_uuid': null,
        'body': 'Welcome everyone',
        'created_at': '2026-07-17T12:00:00Z',
      });

      expect(message.id, 1);
      expect(message.senderKind, SenderKind.guide);
      expect(message.senderId, 7);
      expect(message.senderListenerUuid, isNull);
      expect(message.body, 'Welcome everyone');
      expect(message.createdAt, DateTime.parse('2026-07-17T12:00:00Z'));
    });

    test('parses a listener-sent message (sender is null, uuid is set)', () {
      final message = ChatMessage.fromJson({
        'id': 2,
        'sender_kind': 'listener',
        'sender': null,
        'sender_listener_uuid': 'b3b8c9d0-1234-4a5b-8c6d-000000000000',
        'body': 'Can you hear me?',
        'created_at': '2026-07-17T12:01:00Z',
      });

      expect(message.senderKind, SenderKind.listener);
      expect(message.senderId, isNull);
      expect(message.senderListenerUuid, 'b3b8c9d0-1234-4a5b-8c6d-000000000000');
    });
  });
}
