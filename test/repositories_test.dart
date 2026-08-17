import 'package:ai_support_mobile/core/errors/api_exception.dart';
import 'package:ai_support_mobile/core/network/api_client.dart';
import 'package:ai_support_mobile/features/chat/data/remote_chat_repository.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_stream_event.dart';
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
          '{"documents":[{"id":10,"filename":"refund-policy.pdf","status":"ready","created_at":"2026-08-17T07:42:00Z"}]}',
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

    final documents = await RemoteDocumentRepository(apiClient).listDocuments();
    final chat = await RemoteChatRepository(apiClient)
        .askQuestion('What is the refund policy?');

    expect(documents.single.filename, 'refund-policy.pdf');
    expect(documents.single.id, '10');
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

  test('streaming repository posts SSE request with injected auth header',
      () async {
    final streamingClient = MockClient((request) async {
      expect(request.url.path, '/api/chat/stream');
      expect(request.headers['authorization'], 'Bearer access-token');
      expect(request.headers['accept'], 'text/event-stream');
      expect(request.headers['content-type'], 'application/json');
      expect(request.body, '{"question":"Stream this"}');
      return http.Response(
        'event: start\ndata: {}\n\n'
        'event: delta\ndata: {"text":"Streaming"}\n\n'
        'event: done\ndata: {}\n\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      client: MockClient((_) async => http.Response('{}', 200)),
      streamingClientFactory: () => streamingClient,
      headersProvider: () => {'Authorization': 'Bearer access-token'},
    );

    final session =
        await RemoteChatRepository(apiClient).streamQuestion('Stream this');
    final events = await session.events.toList();

    expect(events, [
      isA<ChatStreamStarted>(),
      isA<ChatStreamDelta>(),
      isA<ChatStreamDone>(),
    ]);
  });

  test('document detail parses metadata', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/documents/doc-1');
      return http.Response(
        '{"document":{"id":"doc-1","filename":"policy.pdf","status":"failed","created_at":"2026-08-17T07:42:00Z","file_size":832000,"mime_type":"application/pdf","chunk_count":4}}',
        200,
      );
    });
    final document = await RemoteDocumentRepository(
      ApiClient(baseUrl: baseUrl, client: client),
    ).getDocument('doc-1');
    expect(document.status.name, 'failed');
    expect(document.fileSize, 832000);
  });

  test('multipart upload uses endpoint, PDF filename, and auth header',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/documents/upload');
      expect(request.headers['authorization'], 'Bearer access-token');
      expect(
          request.headers['content-type'], startsWith('multipart/form-data;'));
      expect(request.body, contains('policy.pdf'));
      return http.Response(
        '{"id":11,"filename":"policy.pdf","status":"ready","created_at":"2026-08-17T07:42:00Z"}',
        201,
      );
    });
    final repository = RemoteDocumentRepository(ApiClient(
      baseUrl: baseUrl,
      client: client,
      headersProvider: () => {'Authorization': 'Bearer access-token'},
    ));
    final document = await repository.uploadPdf(
      filename: 'policy.pdf',
      bytes: [37, 80, 68, 70],
    );
    expect(document.id, '11');
  });

  test('retry and delete use the document endpoints', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add('${request.method} ${request.url.path}');
      if (request.method == 'DELETE') return http.Response('', 204);
      return http.Response(
        '{"document":{"id":"doc-1","filename":"policy.pdf","status":"processing","created_at":"2026-08-17T07:42:00Z"}}',
        200,
      );
    });
    final repository = RemoteDocumentRepository(
      ApiClient(baseUrl: baseUrl, client: client),
    );
    await repository.retryDocument('doc-1');
    await repository.deleteDocument('doc-1');
    expect(methods, [
      'POST /api/documents/doc-1/retry',
      'DELETE /api/documents/doc-1',
    ]);
  });

  for (final statusCode in [409, 413]) {
    test('document API preserves $statusCode for product error mapping',
        () async {
      final client = MockClient((_) async => http.Response('{}', statusCode));
      final repository = RemoteDocumentRepository(
        ApiClient(baseUrl: baseUrl, client: client),
      );
      expect(
        () => repository.retryDocument('doc-1'),
        throwsA(isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          statusCode,
        )),
      );
    });
  }
}
