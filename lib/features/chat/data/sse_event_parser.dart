import 'dart:convert';

import '../../../core/errors/api_exception.dart';
import '../domain/chat_stream_event.dart';
import '../domain/citation.dart';

class SseEventParser {
  const SseEventParser();

  Stream<ChatStreamEvent> parse(Stream<List<int>> byteStream) async* {
    String? eventName;
    final dataLines = <String>[];
    var receivedDone = false;

    await for (final line
        in byteStream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (eventName != null || dataLines.isNotEmpty) {
          final event = _parseFrame(eventName, dataLines.join('\n'));
          if (event != null) {
            if (event is ChatStreamDone) receivedDone = true;
            yield event;
          }
        }
        eventName = null;
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      final separator = line.indexOf(':');
      final field = separator == -1 ? line : line.substring(0, separator);
      var value = separator == -1 ? '' : line.substring(separator + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') eventName = value;
      if (field == 'data') dataLines.add(value);
    }

    if (eventName != null || dataLines.isNotEmpty) {
      final event = _parseFrame(eventName, dataLines.join('\n'));
      if (event != null) {
        if (event is ChatStreamDone) receivedDone = true;
        yield event;
      }
    }
    if (!receivedDone) {
      throw const ApiException(
        'The response stream ended before completion.',
        type: ApiErrorType.invalidResponse,
      );
    }
  }

  ChatStreamEvent? _parseFrame(String? name, String data) {
    if (name == null || name.isEmpty) return null;
    final json = _decodeData(data);
    switch (name) {
      case 'start':
        return ChatStreamStarted(
          conversationId: _optionalId(json['conversation_id'], name),
          userMessageId: _optionalId(json['user_message_id'], name),
          assistantMessageId: _optionalId(json['assistant_message_id'], name),
        );
      case 'delta':
        final text = json['text'];
        if (text is! String) throw _malformed(name);
        return ChatStreamDelta(text);
      case 'citations':
        final rawCitations = json['citations'];
        if (rawCitations is! List) throw _malformed(name);
        final citations = <Citation>[];
        for (final raw in rawCitations) {
          if (raw is! Map) throw _malformed(name);
          final citation = Citation.tryFromJson(raw.cast<String, Object?>());
          if (citation == null) throw _malformed(name);
          citations.add(citation);
        }
        return ChatStreamCitations(citations);
      case 'done':
        return const ChatStreamDone();
      case 'error':
        final message = json['error'];
        return ChatStreamError(
          message is String && message.isNotEmpty
              ? message
              : 'The response stream was interrupted.',
        );
      default:
        return null;
    }
  }

  Map<String, Object?> _decodeData(String data) {
    try {
      final decoded = jsonDecode(data.isEmpty ? '{}' : data);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded.cast<String, Object?>();
    } on FormatException {
      throw const ApiException(
        'The server sent a malformed streaming event.',
        type: ApiErrorType.invalidResponse,
      );
    }
  }

  ApiException _malformed(String event) => ApiException(
        'The server sent an invalid $event event.',
        type: ApiErrorType.invalidResponse,
      );

  String? _optionalId(Object? value, String event) => switch (value) {
        null => null,
        int id => '$id',
        String id when id.isNotEmpty => id,
        _ => throw _malformed(event),
      };
}
