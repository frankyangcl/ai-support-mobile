import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'config/app_config.dart';
import 'network/api_client.dart';
import '../features/auth/presentation/auth_controller.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    client: ref.watch(httpClientProvider),
    headersProvider: () async {
      try {
        final token = await ref.read(authRepositoryProvider).getAccessToken();
        return token == null || token.isEmpty
            ? const <String, String>{}
            : {'Authorization': 'Bearer $token'};
      } catch (_) {
        return const <String, String>{};
      }
    },
  );
});
