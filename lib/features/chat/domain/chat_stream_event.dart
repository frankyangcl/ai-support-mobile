import 'citation.dart';

sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamStarted extends ChatStreamEvent {
  const ChatStreamStarted(
      {this.conversationId, this.userMessageId, this.assistantMessageId});
  final String? conversationId;
  final String? userMessageId;
  final String? assistantMessageId;
}

class ChatStreamDelta extends ChatStreamEvent {
  const ChatStreamDelta(this.text);
  final String text;
}

class ChatStreamCitations extends ChatStreamEvent {
  const ChatStreamCitations(this.citations);
  final List<Citation> citations;
}

class ChatStreamDone extends ChatStreamEvent {
  const ChatStreamDone();
}

class ChatStreamError extends ChatStreamEvent {
  const ChatStreamError(this.message);
  final String message;
}
