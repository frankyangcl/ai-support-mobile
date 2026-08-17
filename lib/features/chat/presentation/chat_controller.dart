import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../data/remote_chat_repository.dart';
import '../domain/chat_message.dart';
import '../domain/chat_repository.dart';
import 'chat_state.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => RemoteChatRepository(ref.watch(apiClientProvider)),
);

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() {
    return const ChatState(
      messages: [
        ChatMessage(
          role: ChatRole.assistant,
          content: 'Hi! Ask me anything about your company documents.',
        ),
      ],
    );
  }

  Future<void> sendMessage(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.isRequesting) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: ChatRole.user, content: question),
      ],
      isRequesting: true,
      clearError: true,
    );
    try {
      final response =
          await ref.read(chatRepositoryProvider).askQuestion(question);
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            role: ChatRole.assistant,
            content: response.answer,
            citations: response.citations,
          ),
        ],
        isRequesting: false,
      );
    } on ApiException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('Unable to get an answer right now. Please try again.');
    }
  }

  void _fail(String message) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        const ChatMessage(
          role: ChatRole.assistant,
          content: 'Unable to get an answer right now. Please try again.',
        ),
      ],
      isRequesting: false,
      errorMessage: message,
    );
  }
}
