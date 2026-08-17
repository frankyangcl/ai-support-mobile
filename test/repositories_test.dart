import 'package:ai_support_mobile/core/errors/api_exception.dart';
import 'package:ai_support_mobile/core/network/api_client.dart';
import 'package:ai_support_mobile/features/chat/data/remote_chat_repository.dart';
import 'package:ai_support_mobile/features/documents/data/remote_document_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'https://api.example.test';

  test('repositories parse successful API responses', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/documents') {
        return http.Response(
          '{"documents":[{"filename":"refund-policy.pdf"}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.path, '/api/chat');
      expect(request.body, '{"question":"What is the refund policy?"}');
      return http.Response(
        '{"answer":"30 days","sources":[{"filename":"refund-policy.pdf"}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final apiClient = ApiClient(baseUrl: baseUrl, client: client);

    final documents = await RemoteDocumentRepository(apiClient).getDocuments();
    final chat = await RemoteChatRepository(apiClient)
        .askQuestion('What is the refund policy?');

    expect(documents.single.filename, 'refund-policy.pdf');
    expect(chat.answer, '30 days');
    expect(chat.citations.single.filename, 'refund-policy.pdf');
  });

  test('API client maps non-2xx responses to ApiException', () async {
    final client = MockClient(
      (_) async => http.Response('{"error":"Service unavailable"}', 503),
    );
    final apiClient = ApiClient(baseUrl: baseUrl, client: client);

    expect(
      () => apiClient.getJson('/api/documents'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having((error) => error.message, 'message', 'Service unavailable'),
      ),
    );
  });

  test('API client rejects invalid JSON responses', () async {
    final client = MockClient((_) async => http.Response('not-json', 200));
    final apiClient = ApiClient(baseUrl: baseUrl, client: client);

    expect(
      () => apiClient.getJson('/api/documents'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.type,
          'type',
          ApiErrorType.invalidResponse,
        ),
      ),
    );
  });
}
