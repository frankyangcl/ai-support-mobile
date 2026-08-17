import 'dart:async';

import 'package:ai_support_mobile/core/errors/api_exception.dart';
import 'package:ai_support_mobile/features/documents/domain/document.dart';
import 'package:ai_support_mobile/features/documents/domain/document_repository.dart';
import 'package:ai_support_mobile/features/documents/presentation/document_file_picker.dart';
import 'package:ai_support_mobile/features/documents/presentation/documents_controller.dart';
import 'package:ai_support_mobile/features/documents/presentation/documents_state.dart';
import 'package:ai_support_mobile/core/observability/analytics_service.dart';
import 'package:ai_support_mobile/core/observability/observability_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial load represents empty success', () async {
    final repository = FakeDocumentRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    container.listen(documentsControllerProvider, (_, __) {});
    await container.read(documentsControllerProvider.notifier).load();
    final state = container.read(documentsControllerProvider);
    expect(state.status, DocumentsLoadStatus.success);
    expect(state.documents, isEmpty);
  });

  test('upload success refreshes and upload failure is productized', () async {
    final repository = FakeDocumentRepository();
    final picker = FakePicker(PickedDocument(filename: 'new.pdf', bytes: [1]));
    final container = _container(repository, picker: picker);
    addTearDown(container.dispose);
    container.listen(documentsControllerProvider, (_, __) {});
    await container.read(documentsControllerProvider.notifier).load();
    repository.documents = [readyDocument];
    expect(
        await container
            .read(documentsControllerProvider.notifier)
            .chooseAndUpload(),
        isTrue);
    expect(
        container.read(documentsControllerProvider).documents, [readyDocument]);

    repository.uploadError =
        const ApiException('large', type: ApiErrorType.server, statusCode: 413);
    expect(
        await container
            .read(documentsControllerProvider.notifier)
            .chooseAndUpload(),
        isFalse);
    expect(container.read(documentsControllerProvider).actionError,
        'The PDF is too large to upload.');
  });

  test('upload analytics is anonymous and reports completed status', () async {
    final analytics = DocumentAnalytics();
    final container = _container(FakeDocumentRepository(), picker: FakePicker(PickedDocument(filename: 'private-name.pdf', bytes: [1])), analytics: analytics);
    addTearDown(container.dispose);
    container.listen(documentsControllerProvider, (_, __) {});
    await container.read(documentsControllerProvider.notifier).load();
    await container.read(documentsControllerProvider.notifier).chooseAndUpload();
    expect(analytics.events.map((item) => item.$1), containsAll(['document_upload_started', 'document_upload_completed']));
    final serialized = analytics.events.toString();
    expect(serialized, isNot(contains('private-name.pdf')));
    expect(serialized, isNot(contains('token')));
  });

  test('retry replaces failed document and delete removes it', () async {
    final repository = FakeDocumentRepository()..documents = [failedDocument];
    final container = _container(repository);
    addTearDown(container.dispose);
    container.listen(documentsControllerProvider, (_, __) {});
    await container.read(documentsControllerProvider.notifier).load();
    repository.retryResult = readyDocument;
    repository.documents = [readyDocument];
    expect(
        await container
            .read(documentsControllerProvider.notifier)
            .retryDocument('doc-1'),
        isTrue);
    expect(container.read(documentsControllerProvider).documents.single.status,
        DocumentStatus.ready);
    expect(
        await container
            .read(documentsControllerProvider.notifier)
            .deleteDocument('doc-1'),
        isTrue);
    expect(container.read(documentsControllerProvider).documents, isEmpty);
  });

  test('duplicate retry is prevented', () async {
    final repository = FakeDocumentRepository()..documents = [failedDocument];
    final completer = Completer<Document>();
    repository.retryCompleter = completer;
    final container = _container(repository);
    addTearDown(container.dispose);
    container.listen(documentsControllerProvider, (_, __) {});
    await container.read(documentsControllerProvider.notifier).load();
    final first = container
        .read(documentsControllerProvider.notifier)
        .retryDocument('doc-1');
    expect(
        await container
            .read(documentsControllerProvider.notifier)
            .retryDocument('doc-1'),
        isFalse);
    expect(repository.retryCalls, 1);
    completer.complete(readyDocument);
    await first;
  });

  test('processing polling refreshes and stops after ready', () async {
    final repository = FakeDocumentRepository()
      ..documents = [processingDocument];
    final container =
        _container(repository, pollInterval: const Duration(milliseconds: 5));
    addTearDown(container.dispose);
    container.listen(documentsControllerProvider, (_, __) {});
    await container.read(documentsControllerProvider.notifier).load();
    repository.documents = [readyDocument];
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final callsAfterReady = repository.listCalls;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repository.listCalls, callsAfterReady);
    expect(container.read(documentsControllerProvider).documents.single.status,
        DocumentStatus.ready);
  });
}

ProviderContainer _container(FakeDocumentRepository repository,
        {DocumentFilePicker? picker, Duration? pollInterval, AnalyticsService? analytics}) =>
    ProviderContainer(overrides: [
      documentRepositoryProvider.overrideWithValue(repository),
      if (picker != null) documentFilePickerProvider.overrideWithValue(picker),
      if (pollInterval != null)
        documentsPollingIntervalProvider.overrideWithValue(pollInterval),
      if (analytics != null) analyticsServiceProvider.overrideWithValue(analytics),
    ]);

class DocumentAnalytics implements AnalyticsService {
  final events = <(String, Map<String, Object>?)>[];
  @override Future<void> logEvent(String name, {Map<String, Object>? parameters}) async => events.add((name, parameters));
}

class FakePicker implements DocumentFilePicker {
  FakePicker(this.result);
  final PickedDocument? result;
  @override
  Future<PickedDocument?> pickPdf() async => result;
}

class FakeDocumentRepository implements DocumentRepository {
  List<Document> documents = [];
  Object? uploadError;
  Document retryResult = readyDocument;
  Completer<Document>? retryCompleter;
  int listCalls = 0;
  int retryCalls = 0;

  @override
  Future<List<Document>> listDocuments() async {
    listCalls++;
    return documents;
  }

  @override
  Future<Document> getDocument(String id) async => documents.single;
  @override
  Future<Document> uploadPdf(
      {required String filename, required List<int> bytes}) async {
    if (uploadError != null) throw uploadError!;
    return readyDocument;
  }

  @override
  Future<Document> retryDocument(String id) {
    retryCalls++;
    return retryCompleter?.future ?? Future.value(retryResult);
  }

  @override
  Future<void> deleteDocument(String id) async {
    documents = documents.where((item) => item.id != id).toList();
  }
}

final readyDocument = Document(
    id: 'doc-1',
    filename: 'policy.pdf',
    status: DocumentStatus.ready,
    createdAt: DateTime(2026, 8, 17),
    chunkCount: 4,
    fileSize: 2517743,
    mimeType: 'application/pdf');
final failedDocument = Document(
    id: 'doc-1',
    filename: 'policy.pdf',
    status: DocumentStatus.failed,
    createdAt: DateTime(2026, 8, 17));
final processingDocument = Document(
    id: 'doc-1',
    filename: 'policy.pdf',
    status: DocumentStatus.processing,
    createdAt: DateTime(2026, 8, 17));
