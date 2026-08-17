enum AuthErrorType { configuration, cancelled, authentication, unknown }

class AuthException implements Exception {
  const AuthException(this.message, {required this.type});

  final String message;
  final AuthErrorType type;

  @override
  String toString() => message;
}
