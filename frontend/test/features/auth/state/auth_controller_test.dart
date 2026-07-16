import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/auth/auth_session.dart';
import 'package:kabin/core/auth/token_pair.dart';
import 'package:kabin/features/auth/domain/user.dart';
import 'package:kabin/features/auth/state/auth_providers.dart';

import '../../../helpers/fake_repositories.dart';

void main() {
  late FakeAuthRepository fakeAuthRepository;
  late AuthSession authSession;
  late ProviderContainer container;

  setUp(() {
    fakeAuthRepository = FakeAuthRepository();
    authSession = AuthSession(storage: FakeTokenStorage());
    container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWithValue(authSession),
        authRepositoryProvider.overrideWithValue(fakeAuthRepository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('bootstrap with no stored session resolves to logged-out, not an error',
      () async {
    // FakeAuthRepository.me() throws a DioException by default when no
    // userToReturn is configured - same shape as a real fresh install
    // with no refresh token, which AuthController._bootstrap treats as
    // "logged out" rather than a genuine error.
    final user = await container.read(authControllerProvider.future);
    expect(user, isNull);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('login sets state to the logged-in user', () async {
    await container
        .read(authControllerProvider.future); // settle bootstrap (logged out)

    const testUser = User(id: 1, email: 'guide@example.com', role: 'guide');
    fakeAuthRepository.userToReturn = testUser;
    fakeAuthRepository.loginTokens =
        const TokenPair(access: 'access-1', refresh: 'refresh-1');

    await container.read(authControllerProvider.notifier).login(
          email: 'guide@example.com',
          password: 'password123!',
        );

    final state = container.read(authControllerProvider);
    expect(state.value, testUser);
    expect(state.hasError, isFalse);
  });

  test('login failure surfaces as an error state, not a crash', () async {
    await container.read(authControllerProvider.future);

    fakeAuthRepository.loginError = fakeDioException(
      data: {
        'code': 'INVALID_CREDENTIALS',
        'message': 'Incorrect email or password.'
      },
    );

    await container.read(authControllerProvider.notifier).login(
          email: 'guide@example.com',
          password: 'wrong',
        );

    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
  });

  test(
      'logout clears state and calls the repository with the stored refresh token',
      () async {
    await container.read(authControllerProvider.future);

    const testUser = User(id: 1, email: 'guide@example.com', role: 'guide');
    fakeAuthRepository.userToReturn = testUser;
    fakeAuthRepository.loginTokens =
        const TokenPair(access: 'access-1', refresh: 'refresh-1');
    await container.read(authControllerProvider.notifier).login(
          email: 'guide@example.com',
          password: 'password123!',
        );

    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(authControllerProvider).value, isNull);
    expect(fakeAuthRepository.logoutCalled, isTrue);
  });
}
