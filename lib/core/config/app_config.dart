import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.auth0Domain,
    required this.auth0ClientId,
    required this.auth0Audience,
  });

  static const defaultApiBaseUrl = 'http://10.0.2.2:8080';
  final String apiBaseUrl;
  final String auth0Domain;
  final String auth0ClientId;
  final String auth0Audience;

  bool get hasAuth0Configuration =>
      auth0Domain.isNotEmpty &&
      auth0ClientId.isNotEmpty &&
      auth0Audience.isNotEmpty;

  factory AppConfig.fromEnvironment() {
    const value = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    );
    const domain = String.fromEnvironment('AUTH0_DOMAIN');
    const clientId = String.fromEnvironment('AUTH0_CLIENT_ID');
    const audience = String.fromEnvironment('AUTH0_AUDIENCE');
    return const AppConfig(
      apiBaseUrl: value,
      auth0Domain: domain,
      auth0ClientId: clientId,
      auth0Audience: audience,
    );
  }
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
