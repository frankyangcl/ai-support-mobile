import '../domain/chat_message.dart';

class ChatState {
  const ChatState({
    required this.messages,
    this.isRequesting = false,
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final bool isRequesting;
  final String? errorMessage;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isRequesting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isRequesting: isRequesting ?? this.isRequesting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
