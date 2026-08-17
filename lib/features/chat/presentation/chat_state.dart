import '../domain/chat_message.dart';

class ChatState {
  const ChatState({
    required this.messages,
    this.activeAssistantMessageId,
    this.errorMessage,
    this.conversationId,
    this.isLoadingHistory = false,
    this.historyError,
  });

  final List<ChatMessage> messages;
  final String? activeAssistantMessageId;
  final String? errorMessage;
  final String? conversationId;
  final bool isLoadingHistory;
  final String? historyError;

  bool get isGenerating => activeAssistantMessageId != null;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? activeAssistantMessageId,
    bool clearActiveMessage = false,
    String? errorMessage,
    bool clearError = false,
    String? conversationId,
    bool clearConversation = false,
    bool? isLoadingHistory,
    String? historyError,
    bool clearHistoryError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      activeAssistantMessageId: clearActiveMessage
          ? null
          : activeAssistantMessageId ?? this.activeAssistantMessageId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      conversationId:
          clearConversation ? null : conversationId ?? this.conversationId,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      historyError:
          clearHistoryError ? null : historyError ?? this.historyError,
    );
  }
}
