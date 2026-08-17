import '../../../core/errors/api_exception.dart';

class Conversation {
  const Conversation(
      {required this.id,
      required this.title,
      required this.createdAt,
      required this.updatedAt});
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Conversation.fromJson(Map<String, Object?> json) {
    final id = _id(json['id']);
    final title = json['title'];
    final createdAt = _date(json['created_at']);
    final updatedAt = _date(json['updated_at']);
    if (id == null ||
        title is! String ||
        createdAt == null ||
        updatedAt == null) {
      throw const ApiException('A conversation in the response is invalid.',
          type: ApiErrorType.invalidResponse);
    }
    return Conversation(
        id: id, title: title, createdAt: createdAt, updatedAt: updatedAt);
  }

  Conversation copyWith({String? title}) => Conversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt);

  static String? _id(Object? value) => switch (value) {
        int id => '$id',
        String id when id.isNotEmpty => id,
        _ => null
      };
  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
