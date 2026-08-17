import 'package:ai_support_mobile/features/chat/domain/chat_response.dart';
import 'package:ai_support_mobile/features/documents/domain/document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('model JSON parsing', () {
    test('parses a document using the existing backend field', () {
      final document = Document.fromJson({'filename': 'shipping-policy.pdf'});
      expect(document.filename, 'shipping-policy.pdf');
    });

    test('parses an answer and de-duplicates valid citations', () {
      final response = ChatResponse.fromJson({
        'answer': 'Standard shipping takes 5 to 7 business days.',
        'sources': [
          {'filename': 'shipping-policy.pdf'},
          {'filename': 'shipping-policy.pdf'},
          <String, Object?>{},
        ],
      });

      expect(response.answer, contains('5 to 7'));
      expect(response.citations, hasLength(1));
      expect(response.citations.single.filename, 'shipping-policy.pdf');
    });
  });
}
