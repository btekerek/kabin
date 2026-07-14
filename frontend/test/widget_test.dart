import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/auth/auth_session.dart';
import 'package:kabin/features/auth/state/auth_providers.dart';
import 'package:kabin/main.dart';

import 'helpers/fake_repositories.dart';

void main() {
  testWidgets('with no stored session, the app boots to the login screen', (tester) async {
    // Real network calls never reach a backend in this test - the fake
    // repository's default me() throws, which AuthController's
    // bootstrap treats as "logged out" (see auth_controller_test.dart
    // for that behavior in isolation). This is a smoke test that the
    // app shell, router, and auth bootstrap wire together correctly.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWithValue(AuthSession(storage: FakeTokenStorage())),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const KabinApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets);
  });
}
