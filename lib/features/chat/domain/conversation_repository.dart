import 'conversation.dart';
import 'persisted_message.dart';

abstract interface class ConversationRepository {
  Future<List<Conversation>> listConversations();
  Future<Conversation> createConversation();
  Future<Conversation> getConversation(String id);
  Future<Conversation> renameConversation(String id, String title);
  Future<void> deleteConversation(String id);
  Future<List<PersistedMessage>> listMessages(String conversationId);
}
