import '../domain/conversation.dart';

enum ConversationListStatus { loading, success, error }

class ConversationsState {
  const ConversationsState(
      {this.status = ConversationListStatus.loading,
      this.items = const [],
      this.activeId,
      this.error,
      this.actionError});
  final ConversationListStatus status;
  final List<Conversation> items;
  final String? activeId;
  final Object? error;
  final String? actionError;

  ConversationsState copyWith(
          {ConversationListStatus? status,
          List<Conversation>? items,
          String? activeId,
          bool clearActive = false,
          Object? error,
          String? actionError,
          bool clearActionError = false}) =>
      ConversationsState(
        status: status ?? this.status,
        items: items ?? this.items,
        activeId: clearActive ? null : activeId ?? this.activeId,
        error: error ?? this.error,
        actionError: clearActionError ? null : actionError ?? this.actionError,
      );
}
