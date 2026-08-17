import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/document.dart';
import '../domain/document_repository.dart';

class RemoteDocumentRepository implements DocumentRepository {
  const RemoteDocumentRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<List<Document>> listDocuments() async {
    final data = await _apiClient.getJson('/api/documents');
    final items = data['documents'];
    if (items is! List) {
      throw const ApiException(
        'The document list in the response is invalid.',
        type: ApiErrorType.invalidResponse,
      );
    }
    return items.map((item) {
      if (item is! Map) {
        throw const ApiException(
          'A document in the response is invalid.',
          type: ApiErrorType.invalidResponse,
        );
      }
      return Document.fromJson(item.cast<String, Object?>());
    }).toList(growable: false);
  }

  @override
  Future<Document> getDocument(String id) async {
    final data =
        await _apiClient.getJson('/api/documents/${Uri.encodeComponent(id)}');
    return _parseDocument(data);
  }

  @override
  Future<Document> uploadPdf(
      {required String filename, required List<int> bytes}) async {
    final data = await _apiClient.uploadMultipart(
      '/api/documents/upload',
      fieldName: 'file',
      filename: filename,
      bytes: bytes,
    );
    return _parseDocument(data);
  }

  @override
  Future<void> deleteDocument(String id) async {
    await _apiClient.deleteJson('/api/documents/${Uri.encodeComponent(id)}');
  }

  @override
  Future<Document> retryDocument(String id) async {
    final data = await _apiClient.postJson(
      '/api/documents/${Uri.encodeComponent(id)}/retry',
      body: const {},
    );
    return _parseDocument(data);
  }

  Document _parseDocument(Map<String, Object?> data) {
    final value = data['document'] ?? data;
    if (value is! Map) {
      throw const ApiException(
        'The document in the response is invalid.',
        type: ApiErrorType.invalidResponse,
      );
    }
    return Document.fromJson(value.cast<String, Object?>());
  }
}
