import 'dart:convert';

import 'package:ai_support_mobile/core/errors/api_exception.dart';
import 'package:ai_support_mobile/features/chat/data/sse_event_parser.dart';
import 'package:ai_support_mobile/features/chat/domain/chat_stream_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = SseEventParser();

  Stream<List<int>> chunks(List<String> values) =>
      Stream.fromIterable(values.map(utf8.encode));

  test('parses start and done events', () async {
    final events = await parser
        .parse(chunks(['event: start\ndata: {}\n\nevent: done\ndata: {}\n\n']))
        .toList();
    expect(events, [isA<ChatStreamStarted>(), isA<ChatStreamDone>()]);
  });

  test('parses integer IDs from the production start event', () async {
    final events = await parser
        .parse(chunks([
          'event: start\ndata: {"conversation_id":123,"user_message_id":456,"assistant_message_id":457}\n\n'
              'event: done\ndata: {}\n\n'
        ]))
        .toList();
    final start = events.first as ChatStreamStarted;
    expect(start.conversationId, '123');
    expect(start.userMessageId, '456');
    expect(start.assistantMessageId, '457');
  });

  test('parses one complete delta event', () async {
    final events = await parser
        .parse(chunks([
          'event: delta\ndata: {"text":"Hello"}\n\n'
              'event: done\ndata: {}\n\n'
        ]))
        .toList();
    expect((events.first as ChatStreamDelta).text, 'Hello');
  });

  test('buffers an event split across network chunks', () async {
    final events = await parser
        .parse(chunks([
          'event: del',
          'ta\ndata: {"te',
          'xt":"split"}\n\n',
          'event: done\ndata: {}\n\n',
        ]))
        .toList();
    expect((events.first as ChatStreamDelta).text, 'split');
  });

  test('parses multiple events from one network chunk', () async {
    final events = await parser
        .parse(chunks([
          'event: delta\ndata: {"text":"A"}\n\n'
              'event: delta\ndata: {"text":"B"}\n\n'
              'event: done\ndata: {}\n\n',
        ]))
        .toList();
    expect(events.whereType<ChatStreamDelta>().map((event) => event.text), [
      'A',
      'B',
    ]);
  });

  test('parses citation fields in backend order', () async {
    final events = await parser
        .parse(chunks([
          'event: citations\n'
              'data: {"citations":[{"document_id":7,"filename":"refund.pdf","chunk_index":2,"distance":0.12,"preview":"Customers may request a refund."}]}\n\n'
              'event: done\ndata: {}\n\n',
        ]))
        .toList();
    final citation = (events.first as ChatStreamCitations).citations.single;
    expect(citation.documentId, 7);
    expect(citation.filename, 'refund.pdf');
    expect(citation.chunkIndex, 2);
    expect(citation.distance, 0.12);
    expect(citation.preview, contains('refund'));
  });

  test('parses error events', () async {
    final events = await parser
        .parse(chunks([
          'event: error\ndata: {"error":"stream interrupted"}\n\n'
              'event: done\ndata: {}\n\n',
        ]))
        .toList();
    expect((events.first as ChatStreamError).message, 'stream interrupted');
  });

  test('ignores keep-alive comments', () async {
    final events = await parser
        .parse(chunks([': keep-alive\n\nevent: done\ndata: {}\n\n']))
        .toList();
    expect(events, [isA<ChatStreamDone>()]);
  });

  test('malformed JSON produces a typed API exception', () {
    expect(
      parser
          .parse(chunks([
            'event: delta\ndata: not-json\n\n',
          ]))
          .toList,
      throwsA(
        isA<ApiException>().having(
          (error) => error.type,
          'type',
          ApiErrorType.invalidResponse,
        ),
      ),
    );
  });

  test('stream close before done is rejected', () {
    expect(
      parser
          .parse(chunks(['event: delta\ndata: {"text":"partial"}\n\n']))
          .toList,
      throwsA(isA<ApiException>()),
    );
  });
}
