import '../../../core/errors/api_exception.dart';
import 'chat_message.dart';
import 'citation.dart';

class PersistedMessage {
  const PersistedMessage(
      {required this.id,
      required this.conversationId,
      required this.role,
      required this.content,
      required this.status,
      required this.citations,
      required this.createdAt});
  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final ChatMessageStatus status;
  final List<Citation> citations;
  final DateTime createdAt;

  factory PersistedMessage.fromJson(Map<String, Object?> json) {
    final id = _id(json['id']);
    final conversationId = _id(json['conversation_id']);
    final role = switch (json['role']) {
      'user' => ChatRole.user,
      'assistant' => ChatRole.assistant,
      _ => null
    };
    final status = switch (json['status']) {
      'processing' => ChatMessageStatus.streaming,
      'completed' => ChatMessageStatus.completed,
      'failed' => ChatMessageStatus.failed,
      'cancelled' => ChatMessageStatus.cancelled,
      _ => null,
    };
    final content = json['content'];
    final createdAt = json['created_at'] is String
        ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
        : null;
    final rawCitations = json['citations'];
    if (id == null ||
        conversationId == null ||
        role == null ||
        status == null ||
        content is! String ||
        createdAt == null ||
        (rawCitations != null && rawCitations is! List)) {
      throw const ApiException('A message in the response is invalid.',
          type: ApiErrorType.invalidResponse);
    }
    final citations = <Citation>[];
    for (final raw in rawCitations as List? ?? const []) {
      if (raw is! Map) {
        throw const ApiException('A message citation is invalid.',
            type: ApiErrorType.invalidResponse);
      }
      final citation = Citation.tryFromJson(raw.cast<String, Object?>());
      if (citation == null) {
        throw const ApiException('A message citation is invalid.',
            type: ApiErrorType.invalidResponse);
      }
      citations.add(citation);
    }
    return PersistedMessage(
        id: id,
        conversationId: conversationId,
        role: role,
        content: content,
        status: status,
        citations: citations,
        createdAt: createdAt);
  }

  ChatMessage toChatMessage({String? replyToMessageId}) => ChatMessage(
      id: id,
      role: role,
      content: content,
      status: status,
      citations: citations,
      replyToMessageId: replyToMessageId,
      createdAt: createdAt,
      isPersisted: true);
  static String? _id(Object? value) => switch (value) {
        int id => '$id',
        String id when id.isNotEmpty => id,
        _ => null
      };
}
