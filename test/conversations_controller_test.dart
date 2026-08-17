import 'package:ai_support_mobile/features/chat/domain/conversation.dart';
import 'package:ai_support_mobile/features/chat/domain/conversation_repository.dart';
import 'package:ai_support_mobile/features/chat/domain/persisted_message.dart';
import 'package:ai_support_mobile/features/chat/presentation/conversations_controller.dart';
import 'package:ai_support_mobile/features/chat/presentation/conversations_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial list, selection, rename, inactive delete, and active delete',
      () async {
    final repository = FakeConversations()..items = [first, second];
    final container = ProviderContainer(overrides: [
      conversationRepositoryProvider.overrideWithValue(repository)
    ]);
    addTearDown(container.dispose);
    container.listen(conversationsControllerProvider, (_, __) {});
    final controller = container.read(conversationsControllerProvider.notifier);
    await controller.load();
    expect(container.read(conversationsControllerProvider).status,
        ConversationListStatus.success);
    expect(container.read(conversationsControllerProvider).items, hasLength(2));

    expect(await controller.select('123'), isEmpty);
    expect(container.read(conversationsControllerProvider).activeId, '123');
    await controller.rename('123', 'Renamed');
    expect(container.read(conversationsControllerProvider).items.first.title,
        'Renamed');
    await controller.delete('124');
    expect(container.read(conversationsControllerProvider).activeId, '123');
    await controller.delete('123');
    expect(container.read(conversationsControllerProvider).activeId, isNull);
  });

  test('new chat does not POST or create an empty backend conversation',
      () async {
    final repository = FakeConversations();
    final container = ProviderContainer(overrides: [
      conversationRepositoryProvider.overrideWithValue(repository)
    ]);
    addTearDown(container.dispose);
    container.listen(conversationsControllerProvider, (_, __) {});
    final controller = container.read(conversationsControllerProvider.notifier);
    controller.activate('123');
    controller.newChat();
    expect(container.read(conversationsControllerProvider).activeId, isNull);
    expect(repository.createCalls, 0);
  });
}

class FakeConversations implements ConversationRepository {
  List<Conversation> items = [];
  int createCalls = 0;
  @override
  Future<List<Conversation>> listConversations() async => items;
  @override
  Future<Conversation> createConversation() async {
    createCalls++;
    return first;
  }

  @override
  Future<Conversation> getConversation(String id) async => first;
  @override
  Future<Conversation> renameConversation(String id, String title) async {
    final old = items.firstWhere((item) => item.id == id);
    final updated = old.copyWith(title: title);
    items = [
      for (final item in items)
        if (item.id == id) updated else item
    ];
    return updated;
  }

  @override
  Future<void> deleteConversation(String id) async {
    items = items.where((item) => item.id != id).toList();
  }

  @override
  Future<List<PersistedMessage>> listMessages(String conversationId) async =>
      [];
}

final first = Conversation(
    id: '123',
    title: 'First',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));
final second = Conversation(
    id: '124',
    title: 'Second',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));
