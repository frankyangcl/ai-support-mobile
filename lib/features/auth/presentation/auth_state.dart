import '../domain/auth_session.dart';

enum AuthStatus {
  checking,
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class AuthState {
  const AuthState({required this.status, this.session, this.errorMessage});

  const AuthState.checking() : this(status: AuthStatus.checking);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
}
