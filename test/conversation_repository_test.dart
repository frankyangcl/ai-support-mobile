import 'package:ai_support_mobile/core/network/api_client.dart';
import 'package:ai_support_mobile/features/chat/data/remote_conversation_repository.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const base = 'https://api.example.test';
  const conversationJson =
      '{"id":123,"title":"Refund policy","created_at":"2026-08-17T08:00:00Z","updated_at":"2026-08-17T09:00:00Z"}';

  test('lists conversations with integer ID and Authorization', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/conversations');
      expect(request.headers['authorization'], 'Bearer token');
      return http.Response('{"conversations":[$conversationJson]}', 200);
    });
    final repository = RemoteConversationRepository(ApiClient(
        baseUrl: base,
        client: client,
        headersProvider: () => {'Authorization': 'Bearer token'}));
    final items = await repository.listConversations();
    expect(items.single.id, '123');
  });

  test('create and get parse conversation envelopes', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      return http.Response('{"conversation":$conversationJson}',
          request.method == 'POST' ? 201 : 200);
    });
    final repository =
        RemoteConversationRepository(ApiClient(baseUrl: base, client: client));
    expect((await repository.createConversation()).id, '123');
    expect((await repository.getConversation('123')).title, 'Refund policy');
    expect(requests, ['POST /api/conversations', 'GET /api/conversations/123']);
  });

  test('rename patches title and delete uses DELETE', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'DELETE') return http.Response('', 204);
      expect(request.body, '{"title":"Returns"}');
      return http.Response('{"conversation":$conversationJson}', 200);
    });
    final repository =
        RemoteConversationRepository(ApiClient(baseUrl: base, client: client));
    await repository.renameConversation('123', 'Returns');
    await repository.deleteConversation('123');
    expect(requests,
        ['PATCH /api/conversations/123', 'DELETE /api/conversations/123']);
  });

  test('restores integer message IDs, failed/cancelled status, and citations',
      () async {
    final client = MockClient((request) async => http.Response('''{"messages":[
      {"id":456,"conversation_id":123,"role":"user","content":"Refund?","status":"completed","citations":[],"created_at":"2026-08-17T08:01:00Z"},
      {"id":457,"conversation_id":123,"role":"assistant","content":"Partial","status":"cancelled","citations":[{"filename":"refund.pdf","preview":"30 days"}],"created_at":"2026-08-17T08:01:01Z"},
      {"id":458,"conversation_id":123,"role":"assistant","content":"","status":"failed","citations":[],"created_at":"2026-08-17T08:01:02Z"}
    ]}''', 200));
    final messages = await RemoteConversationRepository(
            ApiClient(baseUrl: base, client: client))
        .listMessages('123');
    expect(messages.first.id, '456');
    expect(messages.first.conversationId, '123');
    expect(messages[1].status, ChatMessageStatus.cancelled);
    expect(messages[1].citations.single.filename, 'refund.pdf');
    expect(messages[2].status, ChatMessageStatus.failed);
  });
}
