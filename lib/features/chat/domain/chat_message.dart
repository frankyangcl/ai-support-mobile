import 'citation.dart';

enum ChatRole { user, assistant }

enum ChatMessageStatus { sending, streaming, completed, failed, cancelled }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.status,
    this.citations = const [],
    this.replyToMessageId,
    this.createdAt,
    this.isPersisted = false,
  });

  final String id;
  final ChatRole role;
  final String content;
  final ChatMessageStatus status;
  final List<Citation> citations;
  final String? replyToMessageId;
  final DateTime? createdAt;
  final bool isPersisted;

  ChatMessage copyWith({
    String? id,
    String? content,
    ChatMessageStatus? status,
    List<Citation>? citations,
    String? replyToMessageId,
    bool? isPersisted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role,
      content: content ?? this.content,
      status: status ?? this.status,
      citations: citations ?? this.citations,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      createdAt: createdAt,
      isPersisted: isPersisted ?? this.isPersisted,
    );
  }
}
