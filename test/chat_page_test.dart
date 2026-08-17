import 'dart:async';

import 'package:ai_support_mobile/features/chat/domain/chat_repository.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_response.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_stream_event.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_stream_session.dart';
import 'package:ai_support_mobile/features/chat/domain/citation.dart';
import 'package:ai_support_mobile/features/chat/presentation/chat_controller.dart';
import 'package:ai_support_mobile/features/chat/presentation/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('streaming text updates and Stop cancels generation',
      (tester) async {
    final repository = WidgetFakeChatRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ChatPage()),
      ),
    );

    await tester.enterText(find.byKey(const Key('chat-input')), 'Refund?');
    await tester.tap(find.byKey(const Key('send-message')));
    await tester.pump();
    expect(find.byKey(const Key('stop-generation')), findsOneWidget);

    repository.add(const ChatStreamDelta('**30 days**'));
    await tester.pump();
    expect(find.text('30 days'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stop-generation')));
    await tester.pumpAndSettle();
    expect(find.text('Stopped'), findsOneWidget);
    expect(repository.cancelled, isTrue);
  });

  testWidgets('completed response supports citation expansion', (tester) async {
    final repository = WidgetFakeChatRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ChatPage()),
      ),
    );
    await tester.enterText(find.byKey(const Key('chat-input')), 'Shipping?');
    await tester.tap(find.byKey(const Key('send-message')));
    await tester.pump();
    repository
      ..add(const ChatStreamDelta('Answer'))
      ..add(const ChatStreamCitations([
        Citation(filename: 'shipping.pdf', preview: 'Ships in five days.'),
      ]))
      ..add(const ChatStreamDone());
    await repository.close();
    await tester.pumpAndSettle();

    expect(find.text('Sources (1)'), findsOneWidget);
    await tester.ensureVisible(find.text('Sources (1)'));
    await tester.tap(find.text('Sources (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Ships in five days.'), findsOneWidget);
  });
}

class WidgetFakeChatRepository implements ChatRepository {
  bool cancelled = false;
  final _broadcast = StreamController<ChatStreamEvent>.broadcast();

  void add(ChatStreamEvent event) => _broadcast.add(event);
  Future<void> close() => _broadcast.close();

  @override
  Future<ChatResponse> askQuestion(String question,
          {String? conversationId}) async =>
      const ChatResponse(answer: 'fallback');

  @override
  Future<ChatStreamSession> streamQuestion(String question,
      {String? conversationId}) async {
    return ChatStreamSession(
      events: _broadcast.stream,
      cancel: () async {
        cancelled = true;
        await _broadcast.close();
      },
    );
  }
}
