import '../domain/auth_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  AuthException get _error => const AuthException(
        'Auth0 is not configured. Provide AUTH0_DOMAIN, AUTH0_CLIENT_ID, and AUTH0_AUDIENCE.',
        type: AuthErrorType.configuration,
      );

  @override
  Future<String?> getAccessToken() => Future.error(_error);

  @override
  Future<AuthUser?> getCurrentUser() => Future.error(_error);

  @override
  Future<AuthSession> login() => Future.error(_error);

  @override
  Future<void> logout() => Future.error(_error);

  @override
  Future<AuthSession?> restoreSession() => Future.error(_error);
}
