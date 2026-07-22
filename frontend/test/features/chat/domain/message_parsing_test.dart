import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/features/chat/domain/message.dart';

void main() {
  group('senderKindFromJson', () {
    test('parses each backend value', () {
      expect(senderKindFromJson('guide'), SenderKind.guide);
      expect(senderKindFromJson('interpreter'), SenderKind.interpreter);
    });

    test('throws on an unrecognized value', () {
      expect(() => senderKindFromJson('bogus'), throwsArgumentError);
    });
  });

  group('ChatMessage.fromJson', () {
    test('parses a general (channel-less) guide-sent message', () {
      final message = ChatMessage.fromJson({
        'id': 1,
        'channel': null,
        'sender_kind': 'guide',
        'sender': 7,
        'sender_name': 'Guide Person',
        'body': 'Welcome everyone',
        'created_at': '2026-07-17T12:00:00Z',
      });

      expect(message.id, 1);
      expect(message.channelId, isNull);
      expect(message.senderKind, SenderKind.guide);
      expect(message.senderId, 7);
      expect(message.senderName, 'Guide Person');
      expect(message.body, 'Welcome everyone');
      expect(message.createdAt, DateTime.parse('2026-07-17T12:00:00Z'));
    });

    test('parses a channel-scoped interpreter message', () {
      final message = ChatMessage.fromJson({
        'id': 2,
        'channel': 5,
        'sender_kind': 'interpreter',
        'sender': 3,
        'sender_name': 'Relay Person',
        'body': 'Switching in 10 seconds',
        'created_at': '2026-07-17T12:01:00Z',
      });

      expect(message.channelId, 5);
      expect(message.senderKind, SenderKind.interpreter);
      expect(message.senderId, 3);
      expect(message.senderName, 'Relay Person');
    });
  });
}
