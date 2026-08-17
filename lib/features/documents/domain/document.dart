import '../../../core/errors/api_exception.dart';

enum DocumentStatus { processing, ready, failed }

class Document {
  const Document({
    required this.id,
    required this.filename,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.fileSize,
    this.mimeType,
    this.chunkCount,
  });

  final String id;
  final String filename;
  final DocumentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? fileSize;
  final String? mimeType;
  final int? chunkCount;

  factory Document.fromJson(Map<String, Object?> json) {
    final rawId = json['id'];
    final id = switch (rawId) {
      int value => value.toString(),
      String value when value.isNotEmpty => value,
      _ => null,
    };
    final filename = json['filename'];
    final statusValue = json['status'];
    final createdValue = json['created_at'];
    final status = switch (statusValue) {
      'processing' => DocumentStatus.processing,
      'ready' => DocumentStatus.ready,
      'failed' => DocumentStatus.failed,
      _ => null,
    };
    final createdAt = createdValue is String
        ? DateTime.tryParse(createdValue)?.toLocal()
        : null;
    if (id == null ||
        filename is! String ||
        filename.isEmpty ||
        status == null ||
        createdAt == null) {
      throw const ApiException(
        'A document in the response is invalid.',
        type: ApiErrorType.invalidResponse,
      );
    }
    return Document(
      id: id,
      filename: filename,
      status: status,
      createdAt: createdAt,
      updatedAt: _optionalDate(json['updated_at']),
      fileSize: _optionalInt(json['file_size']),
      mimeType:
          json['mime_type'] is String ? json['mime_type'] as String : null,
      chunkCount: _optionalInt(json['chunk_count']),
    );
  }

  static DateTime? _optionalDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static int? _optionalInt(Object? value) => value is int ? value : null;
}
