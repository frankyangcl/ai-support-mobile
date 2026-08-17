import 'chat_response.dart';
import 'chat_stream_session.dart';

abstract interface class ChatRepository {
  Future<ChatResponse> askQuestion(String question, {String? conversationId});
  Future<ChatStreamSession> streamQuestion(String question,
      {String? conversationId});
}
