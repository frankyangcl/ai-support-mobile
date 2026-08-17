import 'document.dart';

abstract interface class DocumentRepository {
  Future<List<Document>> getDocuments();
}
