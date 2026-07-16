import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/network/single_flight_refresh.dart';

void main() {
  group('SingleFlightRefresh', () {
    test('dedupes concurrent calls into a single action invocation', () async {
      var callCount = 0;
      final coordinator = SingleFlightRefresh<int>();
      final completer = Completer<int>();

      Future<int> action() {
        callCount++;
        return completer.future;
      }

      final first = coordinator.run(action);
      final second = coordinator.run(action);

      expect(
        callCount,
        1,
        reason: 'second caller should not start a new action',
      );

      completer.complete(42);

      expect(await first, 42);
      expect(await second, 42);
    });

    test('starts a fresh action after the previous one completes', () async {
      var callCount = 0;
      final coordinator = SingleFlightRefresh<int>();

      Future<int> action() async {
        callCount++;
        return callCount;
      }

      final firstResult = await coordinator.run(action);
      final secondResult = await coordinator.run(action);

      expect(firstResult, 1);
      expect(secondResult, 2);
    });

    test('propagates errors to all awaiters and resets afterwards', () async {
      final coordinator = SingleFlightRefresh<int>();
      final completer = Completer<int>();

      Future<int> failingAction() => completer.future;

      final first = coordinator.run(failingAction);
      final second = coordinator.run(failingAction);

      completer.completeError(StateError('refresh failed'));

      await expectLater(first, throwsA(isA<StateError>()));
      await expectLater(second, throwsA(isA<StateError>()));

      // Coordinator should be usable again after an error.
      final result = await coordinator.run(() async => 7);
      expect(result, 7);
    });
  });
}
