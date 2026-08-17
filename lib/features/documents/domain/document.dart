import '../../../core/errors/api_exception.dart';

class Document {
  const Document({required this.filename});

  final String filename;

  factory Document.fromJson(Map<String, Object?> json) {
    final filename = json['filename'];
    if (filename is! String || filename.isEmpty) {
      throw const ApiException(
        'A document in the response has no valid filename.',
        type: ApiErrorType.invalidResponse,
      );
    }
    return Document(filename: filename);
  }
}
