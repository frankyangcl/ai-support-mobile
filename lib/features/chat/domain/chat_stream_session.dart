import 'dart:async';

import 'chat_stream_event.dart';

class ChatStreamSession {
  const ChatStreamSession({required this.events, required this.cancel});

  final Stream<ChatStreamEvent> events;
  final Future<void> Function() cancel;
}
