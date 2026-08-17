import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.auth0Domain,
    required this.auth0ClientId,
    required this.auth0Audience,
    required this.environment,
  });

  static const defaultApiBaseUrl = 'http://10.0.2.2:8080';
  final String apiBaseUrl;
  final String auth0Domain;
  final String auth0ClientId;
  final String auth0Audience;
  final AppEnvironment environment;

  bool get isProduction => environment == AppEnvironment.production;
  String? get configurationError {
    if (!isProduction) return null;
    if (!hasAuth0Configuration) {
      return 'Production authentication is not configured.';
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.scheme != 'https') {
      return 'Production API_BASE_URL must use HTTPS.';
    }
    return null;
  }

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
    const environmentValue =
        String.fromEnvironment('APP_ENV', defaultValue: 'development');
    return const AppConfig(
      apiBaseUrl: value,
      auth0Domain: domain,
      auth0ClientId: clientId,
      auth0Audience: audience,
      environment: environmentValue == 'production'
          ? AppEnvironment.production
          : AppEnvironment.development,
    );
  }
}

enum AppEnvironment { development, production }

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
