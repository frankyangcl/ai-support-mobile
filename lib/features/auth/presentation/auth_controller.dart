import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/auth0_auth_repository.dart';
import '../data/unconfigured_auth_repository.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_repository.dart';
import 'auth_state.dart';
import '../../../core/observability/observability_providers.dart';
import '../../../core/observability/analytics_service.dart';
import '../../../core/observability/error_reporting_policy.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasAuth0Configuration) {
    return const UnconfiguredAuthRepository();
  }
  return Auth0AuthRepository(
    domain: config.auth0Domain,
    clientId: config.auth0ClientId,
    audience: config.auth0Audience,
  );
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future<void>.microtask(restoreSession);
    return const AuthState.checking();
  }

  Future<void> restoreSession() async {
    state = const AuthState.checking();
    try {
      final session = await ref.read(authRepositoryProvider).restoreSession();
      state = session == null
          ? const AuthState.unauthenticated()
          : AuthState(status: AuthStatus.authenticated, session: session);
    } on AuthException catch (error) {
      state = AuthState(status: AuthStatus.error, errorMessage: error.message);
    } catch (error, stack) {
      await reportIfUnexpected(ref.read(crashReporterProvider), error, stack, reason: 'Auth session restore');
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Unable to restore your sign-in session.',
      );
    }
  }

  Future<void> login() async {
    if (state.status == AuthStatus.authenticating) return;
    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final session = await ref.read(authRepositoryProvider).login();
      state = AuthState(status: AuthStatus.authenticated, session: session);
      await ref.read(analyticsServiceProvider).track('login_success');
    } on AuthException catch (error) {
      state = error.type == AuthErrorType.cancelled
          ? const AuthState.unauthenticated()
          : AuthState(status: AuthStatus.error, errorMessage: error.message);
    } catch (error, stack) {
      await reportIfUnexpected(ref.read(crashReporterProvider), error, stack, reason: 'Auth login');
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Unable to sign in. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
      state = const AuthState.unauthenticated();
      await ref.read(analyticsServiceProvider).track('logout');
    } on AuthException catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        session: state.session,
        errorMessage: error.message,
      );
    }
  }

  void expireSession() {
    state = const AuthState.unauthenticated();
  }
}
