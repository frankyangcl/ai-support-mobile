import '../../../core/network/api_client.dart';
import '../domain/chat_repository.dart';
import '../domain/chat_response.dart';

class RemoteChatRepository implements ChatRepository {
  const RemoteChatRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<ChatResponse> askQuestion(String question) async {
    final data = await _apiClient.postJson(
      '/api/chat',
      body: {'question': question},
    );
    return ChatResponse.fromJson(data);
  }
}
