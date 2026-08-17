import '../../../core/network/api_client.dart';
import '../domain/chat_repository.dart';
import '../domain/chat_response.dart';
import '../domain/chat_stream_session.dart';
import '../domain/chat_stream_event.dart';
import 'sse_event_parser.dart';

class RemoteChatRepository implements ChatRepository {
  const RemoteChatRepository(
    this._apiClient, {
    this.sseParser = const SseEventParser(),
  });
  final ApiClient _apiClient;
  final SseEventParser sseParser;

  @override
  Future<ChatResponse> askQuestion(String question,
      {String? conversationId}) async {
    final data = await _apiClient.postJson(
      '/api/chat',
      body: {
        'question': question,
        if (conversationId != null)
          'conversation_id': int.tryParse(conversationId) ?? conversationId
      },
    );
    return ChatResponse.fromJson(data);
  }

  @override
  Future<ChatStreamSession> streamQuestion(String question,
      {String? conversationId}) async {
    final response = await _apiClient.postJsonStream(
      '/api/chat/stream',
      body: {
        'question': question,
        if (conversationId != null)
          'conversation_id': int.tryParse(conversationId) ?? conversationId
      },
    );

    Stream<ChatStreamEvent> events() async* {
      try {
        yield* sseParser.parse(response.bytes);
      } finally {
        await response.cancel();
      }
    }

    return ChatStreamSession(events: events(), cancel: response.cancel);
  }
}
