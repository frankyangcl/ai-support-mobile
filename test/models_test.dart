import 'package:ai_support_mobile/features/chat/domain/chat_response.dart';
import 'package:ai_support_mobile/features/documents/domain/document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('model JSON parsing', () {
    test('parses a document using the existing backend field', () {
      final document = Document.fromJson({
        'id': 10,
        'filename': 'shipping-policy.pdf',
        'status': 'ready',
        'created_at': '2026-08-17T07:42:00Z',
        'file_size': 2517743,
        'chunk_count': 12,
      });
      expect(document.filename, 'shipping-policy.pdf');
      expect(document.id, '10');
      expect(document.status, DocumentStatus.ready);
      expect(document.chunkCount, 12);
    });

    test('keeps a non-empty string document id for backward compatibility', () {
      final document = Document.fromJson({
        'id': 'doc-legacy',
        'filename': 'legacy.pdf',
        'status': 'ready',
        'created_at': '2026-08-17T07:42:00Z',
      });

      expect(document.id, 'doc-legacy');
    });

    for (final invalidId in <Object?>[null, '', 10.5, true]) {
      test('rejects invalid document id ${invalidId.runtimeType}', () {
        expect(
          () => Document.fromJson({
            'id': invalidId,
            'filename': 'invalid.pdf',
            'status': 'ready',
            'created_at': '2026-08-17T07:42:00Z',
          }),
          throwsA(isA<Exception>()),
        );
      });
    }

    test('parses an answer and de-duplicates valid citations', () {
      final response = ChatResponse.fromJson({
        'answer': 'Standard shipping takes 5 to 7 business days.',
        'conversation_id': 123,
        'user_message_id': 456,
        'assistant_message_id': 457,
        'sources': [
          {'filename': 'shipping-policy.pdf'},
          {'filename': 'shipping-policy.pdf'},
          <String, Object?>{},
        ],
      });

      expect(response.answer, contains('5 to 7'));
      expect(response.citations, hasLength(1));
      expect(response.citations.single.filename, 'shipping-policy.pdf');
      expect(response.conversationId, '123');
      expect(response.userMessageId, '456');
      expect(response.assistantMessageId, '457');
    });
  });
}
