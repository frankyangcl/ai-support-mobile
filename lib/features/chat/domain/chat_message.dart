import 'citation.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.citations = const [],
  });
  final ChatRole role;
  final String content;
  final List<Citation> citations;
}
