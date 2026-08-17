import 'package:auth0_flutter/auth0_flutter.dart';

import '../domain/auth_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

class Auth0AuthRepository implements AuthRepository {
  Auth0AuthRepository({
    required String domain,
    required String clientId,
    required String audience,
  })  : _audience = audience,
        _auth0 = Auth0(domain, clientId);

  final Auth0 _auth0;
  final String _audience;

  @override
  Future<AuthSession?> restoreSession() async {
    try {
      if (!await _auth0.credentialsManager.hasValidCredentials()) return null;
      final credentials = await _auth0.credentialsManager.credentials();
      return _sessionFromCredentials(credentials);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<AuthSession> login() async {
    try {
      final credentials = await _auth0
          .webAuthentication(scheme: 'aisupport')
          .login(audience: _audience);
      return _sessionFromCredentials(credentials);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _auth0.webAuthentication(scheme: 'aisupport').logout();
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      if (!await _auth0.credentialsManager.hasValidCredentials()) return null;
      return (await _auth0.credentialsManager.credentials()).accessToken;
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final session = await restoreSession();
    return session?.user;
  }

  AuthSession _sessionFromCredentials(Credentials credentials) {
    final profile = credentials.user;
    return AuthSession(
      user: AuthUser(
        id: profile.sub,
        name: profile.name,
        email: profile.email,
        pictureUrl: profile.pictureUrl,
      ),
    );
  }

  AuthException _mapError(Object error) {
    if (error is WebAuthenticationException) {
      final code = error.code.toLowerCase();
      if (code.contains('cancel')) {
        return const AuthException(
          'Sign in was cancelled.',
          type: AuthErrorType.cancelled,
        );
      }
      return const AuthException(
        'Authentication failed. Please try again.',
        type: AuthErrorType.authentication,
      );
    }
    return const AuthException(
      'Unable to complete authentication.',
      type: AuthErrorType.unknown,
    );
  }
}
