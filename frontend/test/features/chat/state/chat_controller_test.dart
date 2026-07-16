import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/features/chat/domain/message.dart';
import 'package:kabin/features/chat/state/chat_controller.dart';

import '../../../helpers/fake_repositories.dart';

ChatMessage _message({required int id, String body = 'hi'}) => ChatMessage(
      id: id,
      senderKind: SenderKind.guide,
      senderId: 1,
      senderListenerUuid: null,
      body: body,
      createdAt: DateTime.parse('2026-07-17T12:00:00Z'),
    );

void main() {
  late FakeChatRepository repository;
  late ChatController controller;

  setUp(() {
    repository = FakeChatRepository();
    controller = ChatController(repository: repository, sessionId: 1);
  });

  tearDown(() => controller.dispose());

  // These tests exercise send()/retry()/dismiss() directly without ever
  // calling connect() - that method opens a real ChatSocket, which isn't
  // fakeable without changing ChatController's design (same reason
  // AgoraChannelController has no direct unit tests either). None of the
  // behavior under test here touches the socket.

  test('send() shows a pending message immediately, before the repository resolves',
      () async {
    repository.sendCompleter = Completer<ChatMessage>();

    final future = controller.send(body: 'hello');
    await Future<void>.delayed(Duration.zero);

    expect(controller.pending, hasLength(1));
    expect(controller.pending.first.body, 'hello');
    expect(controller.pending.first.error, isNull);

    repository.sendCompleter!.complete(_message(id: 1, body: 'hello'));
    await future;
  });

  test('a successful send clears the pending entry and upserts the real message',
      () async {
    repository.messageToReturn = _message(id: 5, body: 'hello');

    await controller.send(body: 'hello');

    expect(controller.pending, isEmpty);
    expect(controller.messages, hasLength(1));
    expect(controller.messages.first.id, 5);
  });

  test('a failed send keeps the pending entry with its error set', () async {
    repository.nextSendError = StateError('network down');

    await expectLater(controller.send(body: 'hello'), throwsStateError);

    expect(controller.pending, hasLength(1));
    expect(controller.pending.first.error, isNotNull);
    expect(controller.messages, isEmpty);
  });

  test('retry() after a failure can succeed and clears the pending entry',
      () async {
    repository.nextSendError = StateError('network down');
    await expectLater(controller.send(body: 'hello'), throwsStateError);
    final failed = controller.pending.single;

    repository.messageToReturn = _message(id: 9, body: 'hello');
    await controller.retry(failed);

    expect(controller.pending, isEmpty);
    expect(controller.messages, hasLength(1));
    expect(controller.messages.first.id, 9);
  });

  test('dismiss() removes a failed pending entry without retrying', () async {
    repository.nextSendError = StateError('network down');
    await expectLater(controller.send(body: 'hello'), throwsStateError);

    controller.dismiss(controller.pending.single);

    expect(controller.pending, isEmpty);
    expect(repository.sentBodies, ['hello']);
  });

  test('upserting the same message id twice does not duplicate it', () async {
    // Simulates the REST response and a later WebSocket echo delivering
    // the same server id - the second send below stands in for that
    // echo. Both must collapse to one entry in messages, not two.
    repository.messageToReturn = _message(id: 5, body: 'hello');
    await controller.send(body: 'hello');
    await controller.send(body: 'unused, same id wins');

    expect(controller.messages, hasLength(1));
    expect(controller.messages.first.id, 5);
  });

  // loadOlder() doesn't touch the socket either, so it's testable the
  // same way - seed one message via send() (a non-socket path) to give
  // loadOlder() an "oldest" message to page backward from, standing in
  // for what connect()'s initial history fetch would normally provide.

  test('loadOlder() prepends an older page before the oldest loaded message',
      () async {
    repository.messageToReturn = _message(id: 10, body: 'newest');
    await controller.send(body: 'newest');

    repository.historyToReturn = [
      _message(id: 8, body: 'older'),
      _message(id: 9, body: 'older2'),
    ];
    await controller.loadOlder();

    expect(controller.messages.map((m) => m.id), [8, 9, 10]);
  });

  test('loadOlder() marks history exhausted once a short page comes back',
      () async {
    repository.messageToReturn = _message(id: 10, body: 'newest');
    await controller.send(body: 'newest');

    repository.historyToReturn = []; // nothing older than id 10
    await controller.loadOlder();
    expect(controller.hasMoreHistory, isFalse);

    // A further call is a no-op once exhausted - even if the repository
    // would return something, loadOlder() shouldn't ask again.
    repository.historyToReturn = [_message(id: 1, body: 'should not appear')];
    await controller.loadOlder();
    expect(controller.messages.any((m) => m.id == 1), isFalse);
  });
}
