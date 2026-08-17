import 'package:ai_support_mobile/features/auth/domain/auth_exception.dart';
import 'package:ai_support_mobile/features/auth/domain/auth_repository.dart';
import 'package:ai_support_mobile/features/auth/domain/auth_session.dart';
import 'package:ai_support_mobile/features/auth/domain/auth_user.dart';
import 'package:ai_support_mobile/features/auth/presentation/auth_controller.dart';
import 'package:ai_support_mobile/features/auth/presentation/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user =
      AuthUser(id: 'auth0|user', name: 'Demo User', email: 'demo@example.com');
  const session = AuthSession(user: user);

  Future<ProviderContainer> containerFor(FakeAuthRepository repository) async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('startup restore becomes unauthenticated without credentials', () async {
    final container = await containerFor(FakeAuthRepository());
    expect(container.read(authControllerProvider).status,
        AuthStatus.unauthenticated);
  });

  test('startup restore becomes authenticated with credentials', () async {
    final container = await containerFor(FakeAuthRepository(restored: session));
    expect(
        container.read(authControllerProvider).session?.user.id, 'auth0|user');
  });

  test('login success stores authenticated session in state', () async {
    final container =
        await containerFor(FakeAuthRepository(loginResult: session));
    await container.read(authControllerProvider.notifier).login();
    expect(container.read(authControllerProvider).status,
        AuthStatus.authenticated);
  });

  test('login failure exposes a safe error', () async {
    final container = await containerFor(
      FakeAuthRepository(
        loginError: const AuthException(
          'Authentication failed. Please try again.',
          type: AuthErrorType.authentication,
        ),
      ),
    );
    await container.read(authControllerProvider.notifier).login();
    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.errorMessage, 'Authentication failed. Please try again.');
  });

  test('logout clears authenticated state', () async {
    final repository = FakeAuthRepository(restored: session);
    final container = await containerFor(repository);
    await container.read(authControllerProvider.notifier).logout();
    expect(container.read(authControllerProvider).status,
        AuthStatus.unauthenticated);
    expect(repository.didLogout, isTrue);
  });

  test('AuthUser handles optional profile values', () {
    const minimalUser = AuthUser(id: 'auth0|minimal');
    expect(minimalUser.displayName, 'Signed-in user');
    expect(minimalUser.email, isNull);
    expect(user.displayName, 'Demo User');
  });
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.restored, this.loginResult, this.loginError});

  final AuthSession? restored;
  final AuthSession? loginResult;
  final AuthException? loginError;
  bool didLogout = false;

  @override
  Future<AuthSession?> restoreSession() async => restored;

  @override
  Future<AuthSession> login() async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<void> logout() async => didLogout = true;

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<AuthUser?> getCurrentUser() async => restored?.user;
}
