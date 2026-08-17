import 'document.dart';

abstract interface class DocumentRepository {
  Future<List<Document>> listDocuments();
  Future<Document> getDocument(String id);
  Future<Document> uploadPdf(
      {required String filename, required List<int> bytes});
  Future<void> deleteDocument(String id);
  Future<Document> retryDocument(String id);
}
