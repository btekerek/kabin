import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/features/listener/domain/listener_channel.dart';
import 'package:kabin/features/listener/domain/listener_session_summary.dart';
import 'package:kabin/features/sessions/domain/session.dart';

void main() {
  group('ListenerChannel.fromJson', () {
    test('parses the listener-facing shape (no interpreter_code)', () {
      final channel = ListenerChannel.fromJson({
        'id': 2,
        'language': 'TR',
        'is_source': false,
      });

      expect(channel.id, 2);
      expect(channel.language, 'TR');
      expect(channel.isSource, isFalse);
    });
  });

  group('ListenerSessionSummary.fromJson', () {
    test('parses SessionLookupView\'s response', () {
      final summary = ListenerSessionSummary.fromJson({
        'id': 7,
        'name': 'Kabin Conf',
        'status': 'active',
        'channels': [
          {'id': 1, 'language': 'EN', 'is_source': true},
          {'id': 2, 'language': 'TR', 'is_source': false},
        ],
      });

      expect(summary.id, 7);
      expect(summary.name, 'Kabin Conf');
      expect(summary.status, SessionStatus.active);
      expect(summary.channels, hasLength(2));
      expect(summary.channels.first.isSource, isTrue);
    });
  });
}
