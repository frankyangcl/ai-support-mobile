import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/conversation.dart';
import '../domain/conversation_repository.dart';
import '../domain/persisted_message.dart';

class RemoteConversationRepository implements ConversationRepository {
  const RemoteConversationRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<List<Conversation>> listConversations() async {
    final data = await _apiClient.getJson('/api/conversations');
    return _parseList(
        data['conversations'], Conversation.fromJson, 'conversation');
  }

  @override
  Future<Conversation> createConversation() async => _conversation(
      await _apiClient.postJson('/api/conversations', body: const {}));

  @override
  Future<Conversation> getConversation(String id) async =>
      _conversation(await _apiClient
          .getJson('/api/conversations/${Uri.encodeComponent(id)}'));

  @override
  Future<Conversation> renameConversation(String id, String title) async =>
      _conversation(await _apiClient.patchJson(
          '/api/conversations/${Uri.encodeComponent(id)}',
          body: {'title': title}));

  @override
  Future<void> deleteConversation(String id) async =>
      _apiClient.deleteJson('/api/conversations/${Uri.encodeComponent(id)}');

  @override
  Future<List<PersistedMessage>> listMessages(String conversationId) async {
    final data = await _apiClient.getJson(
        '/api/conversations/${Uri.encodeComponent(conversationId)}/messages');
    return _parseList(data['messages'], PersistedMessage.fromJson, 'message');
  }

  Conversation _conversation(Map<String, Object?> data) {
    final value = data['conversation'] ?? data;
    if (value is! Map) throw _invalid('conversation');
    return Conversation.fromJson(value.cast<String, Object?>());
  }

  List<T> _parseList<T>(
      Object? value, T Function(Map<String, Object?>) parser, String label) {
    if (value is! List) throw _invalid('$label list');
    return value.map((item) {
      if (item is! Map) throw _invalid(label);
      return parser(item.cast<String, Object?>());
    }).toList(growable: false);
  }

  ApiException _invalid(String label) =>
      ApiException('The $label in the response is invalid.',
          type: ApiErrorType.invalidResponse);
}
