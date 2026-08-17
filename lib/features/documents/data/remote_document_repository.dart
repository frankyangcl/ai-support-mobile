import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/document.dart';
import '../domain/document_repository.dart';

class RemoteDocumentRepository implements DocumentRepository {
  const RemoteDocumentRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<List<Document>> getDocuments() async {
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
}
