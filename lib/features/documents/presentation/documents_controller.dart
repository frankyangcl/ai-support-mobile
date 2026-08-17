import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/remote_document_repository.dart';
import '../domain/document.dart';
import '../domain/document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => RemoteDocumentRepository(ref.watch(apiClientProvider)),
);

final documentsControllerProvider =
    AsyncNotifierProvider<DocumentsController, List<Document>>(
  DocumentsController.new,
);

class DocumentsController extends AsyncNotifier<List<Document>> {
  @override
  Future<List<Document>> build() {
    return ref.watch(documentRepositoryProvider).getDocuments();
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(documentRepositoryProvider).getDocuments,
    );
  }
}
