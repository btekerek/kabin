import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/features/sessions/domain/language.dart';
import 'package:kabin/features/sessions/domain/session.dart';

void main() {
  group('Session.fromJson', () {
    test('parses a full SessionSerializer response', () {
      final session = Session.fromJson({
        'id': 7,
        'name': 'Kabin Conf',
        'source_language': 'EN',
        'listener_code': '482913',
        'status': 'not_started',
        'created_at': '2026-07-14T12:00:00Z',
        'channels': [
          {
            'id': 1,
            'session': 7,
            'language': 'EN',
            'interpreter_code': null,
            'is_source': true
          },
          {
            'id': 2,
            'session': 7,
            'language': 'TR',
            'interpreter_code': 'TR117733',
            'is_source': false
          },
        ],
      });

      expect(session.id, 7);
      expect(session.name, 'Kabin Conf');
      expect(session.status, SessionStatus.notStarted);
      expect(session.channels, hasLength(2));
      expect(session.channels.first.isSource, isTrue);
      expect(session.channels.first.interpreterCode, isNull);
      expect(session.channels.last.interpreterCode, 'TR117733');
    });

    test('canStart/canStop/canEnd match the backend state machine', () {
      Session withStatus(String status) => Session.fromJson({
            'id': 1,
            'name': 'x',
            'source_language': 'EN',
            'listener_code': '000000',
            'status': status,
            'created_at': '2026-07-14T12:00:00Z',
            'channels': [],
          });

      final notStarted = withStatus('not_started');
      expect(notStarted.canStart, isTrue);
      expect(notStarted.canStop, isFalse);
      expect(notStarted.canEnd, isTrue);

      final active = withStatus('active');
      expect(active.canStart, isFalse);
      expect(active.canStop, isTrue);
      expect(active.canEnd, isTrue);

      final ended = withStatus('ended');
      expect(ended.canStart, isFalse);
      expect(ended.canStop, isFalse);
      expect(ended.canEnd, isFalse);
    });
  });

  group('Language.fromJson', () {
    test('parses a {code, name} entry', () {
      final language = Language.fromJson({'code': 'TR', 'name': 'Turkish'});
      expect(language.code, 'TR');
      expect(language.name, 'Turkish');
    });
  });
}
