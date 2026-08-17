import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../data/remote_conversation_repository.dart';
import '../domain/conversation_repository.dart';
import '../domain/persisted_message.dart';
import 'conversations_state.dart';
import '../../../core/observability/analytics_service.dart';
import '../../../core/observability/observability_providers.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => RemoteConversationRepository(ref.watch(apiClientProvider)),
);
final conversationsControllerProvider =
    NotifierProvider.autoDispose<ConversationsController, ConversationsState>(
        ConversationsController.new);

class ConversationsController extends AutoDisposeNotifier<ConversationsState> {
  @override
  ConversationsState build() {
    Future<void>.microtask(load);
    return const ConversationsState();
  }

  Future<void> load() async {
    state = state.copyWith(
        status: ConversationListStatus.loading, clearActionError: true);
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final items =
          await ref.read(conversationRepositoryProvider).listConversations();
      state =
          state.copyWith(status: ConversationListStatus.success, items: items);
    } catch (error) {
      if (state.status == ConversationListStatus.success) {
        state = state.copyWith(actionError: conversationErrorMessage(error));
      } else {
        state =
            state.copyWith(status: ConversationListStatus.error, error: error);
      }
    }
  }

  void newChat() =>
      state = state.copyWith(clearActive: true, clearActionError: true);

  Future<List<PersistedMessage>?> select(String id) async {
    state = state.copyWith(activeId: id, clearActionError: true);
    try {
      return await ref.read(conversationRepositoryProvider).listMessages(id);
    } catch (error) {
      state = state.copyWith(actionError: conversationErrorMessage(error));
      return null;
    }
  }

  void activate(String id) => state = state.copyWith(activeId: id);

  Future<bool> rename(String id, String title) async {
    final value = title.trim();
    if (value.isEmpty) return false;
    try {
      final updated = await ref
          .read(conversationRepositoryProvider)
          .renameConversation(id, value);
      state = state.copyWith(items: [
        for (final item in state.items)
          if (item.id == id) updated else item
      ]);
      return true;
    } catch (error) {
      state = state.copyWith(actionError: conversationErrorMessage(error));
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await ref.read(conversationRepositoryProvider).deleteConversation(id);
      await ref.read(analyticsServiceProvider).track('conversation_deleted');
      state = state.copyWith(
          items: state.items.where((item) => item.id != id).toList(),
          clearActive: state.activeId == id);
      return true;
    } catch (error) {
      state = state.copyWith(actionError: conversationErrorMessage(error));
      return false;
    }
  }

  void clearActionError() => state = state.copyWith(clearActionError: true);
}

String conversationErrorMessage(Object? error) {
  if (error is ApiException) {
    if (error.statusCode == 401) return 'Authentication expired.';
    if (error.type == ApiErrorType.network ||
        error.type == ApiErrorType.timeout) {
      return 'Unable to connect.';
    }
  }
  return 'Unable to load conversations.';
}
