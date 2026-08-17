import 'chat_response.dart';

abstract interface class ChatRepository {
  Future<ChatResponse> askQuestion(String question);
}
