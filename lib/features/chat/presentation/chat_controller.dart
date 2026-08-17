import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../data/remote_chat_repository.dart';
import '../domain/chat_message.dart';
import '../domain/chat_repository.dart';
import '../domain/chat_stream_event.dart';
import '../domain/chat_stream_session.dart';
import 'chat_state.dart';
import 'conversations_controller.dart';
import '../../../core/observability/analytics_service.dart';
import '../../../core/observability/observability_providers.dart';
import '../../../core/observability/error_reporting_policy.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => RemoteChatRepository(ref.watch(apiClientProvider)),
);

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  ChatStreamSession? _activeSession;
  StreamSubscription<ChatStreamEvent>? _subscription;
  Completer<void>? _activeCompleter;
  int _nextId = 0;

  @override
  ChatState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _activeSession?.cancel();
    });
    return ChatState(messages: [_welcomeMessage()]);
  }

  Future<void> sendMessage(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.isGenerating) return;
    final userId = _id();
    final assistantId = _id();
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: userId,
          role: ChatRole.user,
          content: question,
          status: ChatMessageStatus.completed,
        ),
        ChatMessage(
          id: assistantId,
          role: ChatRole.assistant,
          content: '',
          status: ChatMessageStatus.sending,
          replyToMessageId: userId,
        ),
      ],
      activeAssistantMessageId: assistantId,
      clearError: true,
    );
    await _startStream(question, assistantId);
  }

  Future<void> newChat() async {
    await stopGeneration();
    ref.read(conversationsControllerProvider.notifier).newChat();
    state = ChatState(messages: [_welcomeMessage()]);
  }

  Future<bool> loadConversation(String id) async {
    await stopGeneration();
    state = state.copyWith(isLoadingHistory: true, clearHistoryError: true);
    final persisted =
        await ref.read(conversationsControllerProvider.notifier).select(id);
    if (persisted == null) {
      state = state.copyWith(
          isLoadingHistory: false, historyError: 'Unable to load messages.');
      return false;
    }
    String? latestUserId;
    final messages = <ChatMessage>[];
    for (final item in persisted) {
      if (item.role == ChatRole.user) latestUserId = item.id;
      messages.add(item.toChatMessage(
          replyToMessageId:
              item.role == ChatRole.assistant ? latestUserId : null));
    }
    state = ChatState(messages: messages, conversationId: id);
    return true;
  }

  bool canRetry(String assistantId) {
    final message = _messageById(assistantId);
    return state.conversationId == null &&
        message != null &&
        !message.isPersisted;
  }

  Future<void> retryMessage(String assistantMessageId) async {
    if (state.isGenerating || !canRetry(assistantMessageId)) return;
    final assistant = _messageById(assistantMessageId);
    if (assistant == null || assistant.status != ChatMessageStatus.failed) {
      return;
    }
    final question = _messageById(assistant.replyToMessageId ?? '');
    if (question == null || question.role != ChatRole.user) return;
    _updateMessage(
      assistantMessageId,
      (message) => message.copyWith(
        content: '',
        citations: const [],
        status: ChatMessageStatus.sending,
      ),
      activeId: assistantMessageId,
      clearError: true,
    );
    await ref.read(analyticsServiceProvider).track('generation_stopped');
    await _startStream(question.content, assistantMessageId);
  }

  Future<void> stopGeneration() async {
    final activeId = state.activeAssistantMessageId;
    if (activeId == null) return;
    final subscription = _subscription;
    final session = _activeSession;
    _subscription = null;
    _activeSession = null;
    _updateMessage(
      activeId,
      (message) => message.copyWith(status: ChatMessageStatus.cancelled),
      clearActive: true,
      clearError: true,
    );
    if (!(_activeCompleter?.isCompleted ?? true)) {
      _activeCompleter!.complete();
    }
    _activeCompleter = null;
    final cancelTransport = session?.cancel();
    final cancelSubscription = subscription?.cancel();
    await cancelTransport;
    await cancelSubscription;
  }

  Future<void> _startStream(String question, String assistantId) async {
    Completer<void>? streamCompleter;
    try {
      final session = await ref.read(chatRepositoryProvider).streamQuestion(
            question,
            conversationId: state.conversationId,
          );
      if (state.activeAssistantMessageId != assistantId) {
        await session.cancel();
        return;
      }
      _activeSession = session;
      final completer = Completer<void>();
      streamCompleter = completer;
      _activeCompleter = completer;
      _subscription = session.events.listen(
        (event) => _handleEvent(assistantId, event),
        onError: (Object error, StackTrace stack) {
          unawaited(reportIfUnexpected(ref.read(crashReporterProvider), error, stack, reason: 'Chat stream'));
          final failedId = state.activeAssistantMessageId ?? assistantId;
          _fail(failedId, _messageForError(error));
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
    } catch (error, stack) {
      await reportIfUnexpected(ref.read(crashReporterProvider), error, stack, reason: 'Chat request');
      _fail(assistantId, _messageForError(error));
    } finally {
      final activeId = state.activeAssistantMessageId;
      if (activeId != null) {
        final message = _messageById(activeId);
        if (message != null &&
            message.status != ChatMessageStatus.completed &&
            message.status != ChatMessageStatus.failed &&
            message.status != ChatMessageStatus.cancelled) {
          _fail(activeId, 'Response interrupted. Retry.');
        }
      }
      _subscription = null;
      _activeSession = null;
      if (identical(_activeCompleter, streamCompleter)) {
        _activeCompleter = null;
      }
    }
  }

  void _handleEvent(String _, ChatStreamEvent event) {
    final activeId = state.activeAssistantMessageId;
    if (activeId == null) return;
    switch (event) {
      case ChatStreamStarted(
          :final conversationId,
          :final userMessageId,
          :final assistantMessageId
        ):
        final assistant = _messageById(activeId);
        if (assistant == null) return;
        final userLocalId = assistant.replyToMessageId;
        final isNewConversation = state.conversationId == null;
        final newAssistantId = assistantMessageId ?? activeId;
        final newUserId = userMessageId ?? userLocalId;
        state = state.copyWith(
          conversationId: conversationId,
          activeAssistantMessageId: newAssistantId,
          messages: [
            for (final message in state.messages)
              if (message.id == userLocalId && newUserId != null)
                message.copyWith(
                    id: newUserId, isPersisted: userMessageId != null)
              else if (message.id == activeId)
                message.copyWith(
                    id: newAssistantId,
                    replyToMessageId: newUserId,
                    status: ChatMessageStatus.streaming,
                    isPersisted: assistantMessageId != null)
              else
                message,
          ],
        );
        if (conversationId != null) {
          if (isNewConversation) {
            unawaited(ref
                .read(analyticsServiceProvider)
                .track('conversation_started'));
          }
          ref.read(conversationsControllerProvider.notifier)
            ..activate(conversationId)
            ..refresh();
        }
      case ChatStreamDelta(:final text):
        _updateMessage(
          state.activeAssistantMessageId!,
          (message) => message.copyWith(
            content: '${message.content}$text',
            status: ChatMessageStatus.streaming,
          ),
        );
      case ChatStreamCitations(:final citations):
        _updateMessage(
          state.activeAssistantMessageId!,
          (message) => message.copyWith(citations: citations),
        );
      case ChatStreamDone():
        unawaited(
            ref.read(analyticsServiceProvider).track('conversation_completed'));
        _updateMessage(
          state.activeAssistantMessageId!,
          (message) => message.copyWith(status: ChatMessageStatus.completed),
          clearActive: true,
          clearError: true,
        );
      case ChatStreamError(:final message):
        _fail(state.activeAssistantMessageId!, message);
    }
  }

  void _fail(String assistantId, String message) {
    if (_messageById(assistantId) == null) return;
    _updateMessage(
      assistantId,
      (item) => item.copyWith(status: ChatMessageStatus.failed),
      clearActive: true,
      errorMessage: message,
    );
  }

  String _messageForError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return 'Authentication expired. Sign in again.';
      }
      if (error.statusCode == 409) {
        return 'A response is already being generated.';
      }
      if (error.type == ApiErrorType.network) {
        return 'Unable to connect. Retry.';
      }
    }
    return 'Response interrupted. Retry.';
  }

  void _updateMessage(
    String id,
    ChatMessage Function(ChatMessage) update, {
    String? activeId,
    bool clearActive = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          if (message.id == id) update(message) else message,
      ],
      activeAssistantMessageId: activeId,
      clearActiveMessage: clearActive,
      errorMessage: errorMessage,
      clearError: clearError,
    );
  }

  ChatMessage? _messageById(String id) {
    for (final message in state.messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  ChatMessage _welcomeMessage() => ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        content: ref.read(remoteSettingsProvider).welcomeMessage,
        status: ChatMessageStatus.completed,
      );
}
