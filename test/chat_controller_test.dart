import 'dart:async';

import 'package:ai_support_mobile/features/chat/domain/chat_message.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_repository.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_response.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_stream_event.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_stream_session.dart';
import 'package:ai_support_mobile/features/chat/domain/citation.dart';
import 'package:ai_support_mobile/features/chat/domain/conversation.dart';
import 'package:ai_support_mobile/features/chat/domain/conversation_repository.dart';
import 'package:ai_support_mobile/features/chat/domain/persisted_message.dart';
import 'package:ai_support_mobile/features/chat/presentation/chat_controller.dart';
import 'package:ai_support_mobile/features/chat/presentation/conversations_controller.dart';
import 'package:ai_support_mobile/core/observability/analytics_service.dart';
import 'package:ai_support_mobile/core/observability/observability_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeChatRepository repository;
  late ProviderContainer container;
  late FakeConversationRepository conversations;
  late ChatAnalytics analytics;

  setUp(() {
    repository = FakeChatRepository();
    conversations = FakeConversationRepository();
    analytics = ChatAnalytics();
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repository),
        conversationRepositoryProvider.overrideWithValue(conversations),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    container.read(chatControllerProvider);
  });

  tearDown(() => container.dispose());

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('send immediately adds user and assistant lifecycle messages', () async {
    unawaited(
        container.read(chatControllerProvider.notifier).sendMessage('Hi'));
    await flush();
    final state = container.read(chatControllerProvider);
    expect(state.messages[state.messages.length - 2].content, 'Hi');
    expect(state.messages.last.status, ChatMessageStatus.sending);
    expect(state.isGenerating, isTrue);
  });

  test('delta appends to one assistant and citations update it', () async {
    final future =
        container.read(chatControllerProvider.notifier).sendMessage('Refund?');
    await flush();
    final stream = repository.sessions.single;
    stream.add(const ChatStreamStarted());
    stream.add(const ChatStreamDelta('30 '));
    stream.add(const ChatStreamDelta('days'));
    stream.add(const ChatStreamCitations([
      Citation(filename: 'refund.pdf', preview: 'Refunds are allowed.'),
    ]));
    await flush();
    final assistant = container.read(chatControllerProvider).messages.last;
    expect(assistant.content, '30 days');
    expect(assistant.citations.single.filename, 'refund.pdf');
    expect(assistant.status, ChatMessageStatus.streaming);
    stream.add(const ChatStreamDone());
    await stream.close();
    await future;
    expect(
      container.read(chatControllerProvider).messages.last.status,
      ChatMessageStatus.completed,
    );
  });

  test('stream error marks assistant failed', () async {
    final future =
        container.read(chatControllerProvider.notifier).sendMessage('Fail');
    await flush();
    final stream = repository.sessions.single;
    stream.add(const ChatStreamError('interrupted'));
    await stream.close();
    await future;
    expect(container.read(chatControllerProvider).messages.last.status,
        ChatMessageStatus.failed);
  });

  test('stop cancels transport and preserves partial text', () async {
    final future =
        container.read(chatControllerProvider.notifier).sendMessage('Stop');
    await flush();
    final stream = repository.sessions.single;
    stream.add(const ChatStreamDelta('Partial'));
    await flush();
    await container.read(chatControllerProvider.notifier).stopGeneration();
    await future;
    final assistant = container.read(chatControllerProvider).messages.last;
    expect(assistant.content, 'Partial');
    expect(assistant.status, ChatMessageStatus.cancelled);
    expect(stream.cancelled, isTrue);
  });

  test('retry reuses failed assistant and original user question', () async {
    final first =
        container.read(chatControllerProvider.notifier).sendMessage('Original');
    await flush();
    repository.sessions.first.add(const ChatStreamError('failed'));
    await repository.sessions.first.close();
    await first;
    final failedId = container.read(chatControllerProvider).messages.last.id;
    final messageCount = container.read(chatControllerProvider).messages.length;

    final retry =
        container.read(chatControllerProvider.notifier).retryMessage(failedId);
    await flush();
    expect(repository.questions, ['Original', 'Original']);
    repository.sessions.last
      ..add(const ChatStreamDelta('Recovered'))
      ..add(const ChatStreamDone());
    await repository.sessions.last.close();
    await retry;
    final state = container.read(chatControllerProvider);
    expect(state.messages, hasLength(messageCount));
    expect(state.messages.last.content, 'Recovered');
    expect(state.messages.last.status, ChatMessageStatus.completed);
  });

  test('prevents parallel sends', () async {
    unawaited(
        container.read(chatControllerProvider.notifier).sendMessage('One'));
    await flush();
    await container.read(chatControllerProvider.notifier).sendMessage('Two');
    expect(repository.questions, ['One']);
    await container.read(chatControllerProvider.notifier).stopGeneration();
  });

  test('first start binds backend IDs and subsequent send reuses conversation',
      () async {
    final first =
        container.read(chatControllerProvider.notifier).sendMessage('First');
    await flush();
    repository.sessions.first
      ..add(const ChatStreamStarted(
          conversationId: '123',
          userMessageId: '456',
          assistantMessageId: '457'))
      ..add(const ChatStreamDone());
    await repository.sessions.first.close();
    await first;
    var state = container.read(chatControllerProvider);
    expect(state.conversationId, '123');
    expect(state.messages[state.messages.length - 2].id, '456');
    expect(state.messages.last.id, '457');
    expect(analytics.events, contains('conversation_started'));

    final second =
        container.read(chatControllerProvider.notifier).sendMessage('Second');
    await flush();
    expect(repository.conversationIds, [null, '123']);
    repository.sessions.last.add(const ChatStreamDone());
    await repository.sessions.last.close();
    await second;
  });

  test('loads persisted history and new chat clears active conversation',
      () async {
    conversations.messages = [
      PersistedMessage(
          id: '456',
          conversationId: '123',
          role: ChatRole.user,
          content: 'Question',
          status: ChatMessageStatus.completed,
          citations: const [],
          createdAt: DateTime(2026)),
      PersistedMessage(
          id: '457',
          conversationId: '123',
          role: ChatRole.assistant,
          content: 'Stopped partial',
          status: ChatMessageStatus.cancelled,
          citations: const [Citation(filename: 'policy.pdf')],
          createdAt: DateTime(2026)),
    ];
    expect(
        await container
            .read(chatControllerProvider.notifier)
            .loadConversation('123'),
        isTrue);
    var state = container.read(chatControllerProvider);
    expect(state.conversationId, '123');
    expect(state.messages.last.status, ChatMessageStatus.cancelled);
    expect(state.messages.last.citations, hasLength(1));
    await container.read(chatControllerProvider.notifier).newChat();
    state = container.read(chatControllerProvider);
    expect(state.conversationId, isNull);
    expect(state.messages, hasLength(1));
  });
}

class ChatAnalytics implements AnalyticsService {
  final events = <String>[];
  @override Future<void> logEvent(String name, {Map<String, Object>? parameters}) async => events.add(name);
}

class FakeChatRepository implements ChatRepository {
  final sessions = <FakeStreamSession>[];
  final questions = <String>[];
  final conversationIds = <String?>[];

  @override
  Future<ChatResponse> askQuestion(String question,
          {String? conversationId}) async =>
      const ChatResponse(answer: 'fallback');

  @override
  Future<ChatStreamSession> streamQuestion(String question,
      {String? conversationId}) async {
    questions.add(question);
    conversationIds.add(conversationId);
    final session = FakeStreamSession();
    sessions.add(session);
    return ChatStreamSession(events: session.stream, cancel: session.cancel);
  }
}

class FakeConversationRepository implements ConversationRepository {
  List<Conversation> conversations = [];
  List<PersistedMessage> messages = [];
  @override
  Future<List<Conversation>> listConversations() async => conversations;
  @override
  Future<Conversation> createConversation() => throw UnimplementedError();
  @override
  Future<Conversation> getConversation(String id) => throw UnimplementedError();
  @override
  Future<Conversation> renameConversation(String id, String title) =>
      throw UnimplementedError();
  @override
  Future<void> deleteConversation(String id) async {}
  @override
  Future<List<PersistedMessage>> listMessages(String conversationId) async =>
      messages;
}

class FakeStreamSession {
  final _controller = StreamController<ChatStreamEvent>();
  bool cancelled = false;

  Stream<ChatStreamEvent> get stream => _controller.stream;
  void add(ChatStreamEvent event) => _controller.add(event);
  Future<void> close() => _controller.close();

  Future<void> cancel() async {
    cancelled = true;
    await _controller.close();
  }
}
