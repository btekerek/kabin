import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/features/sessions/domain/session.dart';
import 'package:kabin/features/sessions/state/session_providers.dart';

import '../../../helpers/fake_repositories.dart';

Map<String, dynamic> _sessionJson({required int id, required String status}) =>
    {
      'id': id,
      'name': 'Kabin Conf',
      'source_language': 'EN',
      'listener_code': '482913',
      'status': status,
      'created_at': '2026-07-14T12:00:00Z',
      'channels': [
        {
          'id': 10,
          'language': 'EN',
          'interpreter_code': 'EN482913',
          'is_source': true
        },
      ],
    };

void main() {
  late FakeSessionRepository fakeSessionRepository;
  late ProviderContainer container;

  setUp(() {
    fakeSessionRepository = FakeSessionRepository();
    container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(fakeSessionRepository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('build fetches the session by id', () async {
    fakeSessionRepository.sessionToReturn = Session.fromJson(
      _sessionJson(id: 1, status: 'not_started'),
    );

    final session = await container.read(sessionDetailProvider(1).future);

    expect(session.id, 1);
    expect(session.status, SessionStatus.notStarted);
    expect(fakeSessionRepository.calledActions, contains('get:1'));
  });

  test('start() calls the repository and updates state to the returned session',
      () async {
    fakeSessionRepository.sessionToReturn = Session.fromJson(
      _sessionJson(id: 1, status: 'not_started'),
    );
    await container.read(sessionDetailProvider(1).future);

    fakeSessionRepository.sessionToReturn = Session.fromJson(
      _sessionJson(id: 1, status: 'active'),
    );
    await container.read(sessionDetailProvider(1).notifier).start();

    final state = container.read(sessionDetailProvider(1));
    expect(state.value?.status, SessionStatus.active);
    expect(fakeSessionRepository.calledActions, contains('start:1'));
  });

  test('a failed transition surfaces as an error state', () async {
    fakeSessionRepository.sessionToReturn = Session.fromJson(
      _sessionJson(id: 1, status: 'ended'),
    );
    await container.read(sessionDetailProvider(1).future);

    fakeSessionRepository.nextError = fakeDioException(
      data: {
        'code': 'INVALID_TRANSITION',
        'message': "Cannot go from 'ended' to 'active'."
      },
    );
    await container.read(sessionDetailProvider(1).notifier).start();

    expect(container.read(sessionDetailProvider(1)).hasError, isTrue);
  });
}
