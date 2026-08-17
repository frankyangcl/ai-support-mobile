import '../../../core/errors/api_exception.dart';
import 'citation.dart';

class ChatResponse {
  const ChatResponse({required this.answer, this.citations = const []});
  final String answer;
  final List<Citation> citations;

  factory ChatResponse.fromJson(Map<String, Object?> json) {
    final answer = json['answer'];
    if (answer is! String) {
      throw const ApiException(
        'The chat response has no valid answer.',
        type: ApiErrorType.invalidResponse,
      );
    }
    final rawSources = json['sources'];
    if (rawSources != null && rawSources is! List) {
      throw const ApiException(
        'The sources in the chat response are invalid.',
        type: ApiErrorType.invalidResponse,
      );
    }
    final citations = <Citation>[];
    final seen = <String>{};
    if (rawSources is List) {
      for (final source in rawSources) {
        if (source is! Map) continue;
        final citation = Citation.tryFromJson(source.cast<String, Object?>());
        if (citation != null && seen.add(citation.filename)) {
          citations.add(citation);
        }
      }
    }
    return ChatResponse(answer: answer, citations: citations);
  }
}
