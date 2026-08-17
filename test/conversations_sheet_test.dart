import 'package:ai_support_mobile/features/chat/domain/conversation.dart';
import 'package:ai_support_mobile/features/chat/domain/conversation_repository.dart';
import 'package:ai_support_mobile/features/chat/domain/persisted_message.dart';
import 'package:ai_support_mobile/features/chat/presentation/chat_page.dart';
import 'package:ai_support_mobile/features/chat/presentation/conversations_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('conversation launcher shows list and New chat', (tester) async {
    await _pump(tester, SheetRepository([conversation]));
    expect(find.byKey(const Key('conversations-launcher')), findsOneWidget);
    await tester.tap(find.byKey(const Key('conversations-launcher')));
    await tester.pumpAndSettle();
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Refund policy'), findsOneWidget);
    expect(find.byKey(const Key('new-chat')), findsOneWidget);
  });

  testWidgets('empty conversation list gives friendly guidance',
      (tester) async {
    await _pump(tester, SheetRepository([]));
    await tester.tap(find.byKey(const Key('conversations-launcher')));
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Start a conversation with AI Support.'), findsOneWidget);
  });

  testWidgets('conversation menu opens rename dialog', (tester) async {
    await _pump(tester, SheetRepository([conversation]));
    await tester.tap(find.byKey(const Key('conversations-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Rename conversation'), findsOneWidget);
    expect(find.byKey(const Key('rename-input')), findsOneWidget);
  });

  testWidgets('conversation menu requires delete confirmation', (tester) async {
    await _pump(tester, SheetRepository([conversation]));
    await tester.tap(find.byKey(const Key('conversations-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Refund policy"?'), findsOneWidget);
    expect(
        find.text(
            'This will permanently delete this conversation and its messages.'),
        findsOneWidget);
  });
}

Future<void> _pump(
    WidgetTester tester, ConversationRepository repository) async {
  await tester.pumpWidget(ProviderScope(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: ChatPage())));
  await tester.pumpAndSettle();
}

class SheetRepository implements ConversationRepository {
  SheetRepository(this.items);
  final List<Conversation> items;
  @override
  Future<List<Conversation>> listConversations() async => items;
  @override
  Future<Conversation> createConversation() => throw UnimplementedError();
  @override
  Future<Conversation> getConversation(String id) async => conversation;
  @override
  Future<Conversation> renameConversation(String id, String title) async =>
      conversation.copyWith(title: title);
  @override
  Future<void> deleteConversation(String id) async {}
  @override
  Future<List<PersistedMessage>> listMessages(String conversationId) async =>
      [];
}

final conversation = Conversation(
    id: '123',
    title: 'Refund policy',
    createdAt: DateTime(2026, 8, 17),
    updatedAt: DateTime(2026, 8, 17));
