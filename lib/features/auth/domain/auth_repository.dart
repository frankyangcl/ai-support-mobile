import 'auth_session.dart';
import 'auth_user.dart';

abstract interface class AuthRepository {
  Future<AuthSession?> restoreSession();
  Future<AuthSession> login();
  Future<void> logout();
  Future<String?> getAccessToken();
  Future<AuthUser?> getCurrentUser();
}
