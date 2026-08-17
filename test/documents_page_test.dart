import 'package:ai_support_mobile/features/documents/domain/document.dart';
import 'package:ai_support_mobile/features/documents/domain/document_repository.dart';
import 'package:ai_support_mobile/features/documents/presentation/document_file_picker.dart';
import 'package:ai_support_mobile/features/documents/presentation/documents_controller.dart';
import 'package:ai_support_mobile/features/documents/presentation/documents_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_support_mobile/core/observability/observability_providers.dart';
import 'package:ai_support_mobile/core/observability/remote_config_service.dart';

void main() {
  testWidgets('empty state guides upload and Add document opens picker',
      (tester) async {
    final repository = WidgetRepository([]);
    final picker = WidgetPicker();
    await _pump(tester, repository, picker: picker);
    expect(find.text('No documents yet'), findsOneWidget);
    expect(find.text('Upload a PDF to build your knowledge base.'),
        findsOneWidget);
    expect(find.text('Add document'), findsNWidgets(2));
    await tester.tap(find.text('Add document').first);
    await tester.pump();
    expect(picker.calls, 1);
  });

  testWidgets('cards show Processing, Ready metadata, and Failed Retry',
      (tester) async {
    await _pump(tester, WidgetRepository([processing, ready, failed]));
    expect(find.text('Processing'), findsOneWidget);
    expect(find.text('Ready · 4 chunks'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);
  });

  testWidgets('detail shows safe metadata and delete confirmation',
      (tester) async {
    await _pump(tester, WidgetRepository([ready]));
    await tester.tap(find.byKey(const ValueKey('document-ready')));
    await tester.pumpAndSettle();
    expect(find.text('2.4 MB'), findsOneWidget);
    expect(find.text('application/pdf'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "ready.pdf"?'), findsOneWidget);
    expect(find.text('This will remove the document from the knowledge base.'),
        findsOneWidget);
  });

  testWidgets('pull to refresh reloads documents', (tester) async {
    final repository = WidgetRepository([ready]);
    await _pump(tester, repository);
    final initialCalls = repository.listCalls;
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(repository.listCalls, greaterThan(initialCalls));
  });

  testWidgets('chat feature flag disables only chat entry', (tester) async {
    await _pump(tester, WidgetRepository([]), remote: const RemoteSettings(chatFeatureEnabled: false));
    await tester.tap(find.text('Start Conversation'));
    await tester.pump();
    expect(find.text('Chat is temporarily unavailable.'), findsOneWidget);
    expect(find.text('Knowledge Base'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, WidgetRepository repository,
    {WidgetPicker? picker, RemoteSettings? remote}) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    documentRepositoryProvider.overrideWithValue(repository),
    if (picker != null) documentFilePickerProvider.overrideWithValue(picker),
    if (remote != null) remoteConfigServiceProvider.overrideWithValue(LocalRemoteConfigService(remote)),
  ], child: const MaterialApp(home: DocumentsPage())));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class WidgetPicker implements DocumentFilePicker {
  int calls = 0;
  @override
  Future<PickedDocument?> pickPdf() async {
    calls++;
    return null;
  }
}

class WidgetRepository implements DocumentRepository {
  WidgetRepository(this.documents);
  List<Document> documents;
  int listCalls = 0;
  @override
  Future<List<Document>> listDocuments() async {
    listCalls++;
    return documents;
  }

  @override
  Future<Document> getDocument(String id) async =>
      documents.firstWhere((item) => item.id == id);
  @override
  Future<Document> uploadPdf(
          {required String filename, required List<int> bytes}) async =>
      ready;
  @override
  Future<Document> retryDocument(String id) async => ready;
  @override
  Future<void> deleteDocument(String id) async {
    documents = documents.where((item) => item.id != id).toList();
  }
}

final processing = Document(
    id: 'processing',
    filename: 'processing.pdf',
    status: DocumentStatus.processing,
    createdAt: DateTime(2026, 8, 17));
final ready = Document(
    id: 'ready',
    filename: 'ready.pdf',
    status: DocumentStatus.ready,
    createdAt: DateTime(2026, 8, 17, 15, 42),
    updatedAt: DateTime(2026, 8, 17, 16),
    fileSize: 2517743,
    mimeType: 'application/pdf',
    chunkCount: 4);
final failed = Document(
    id: 'failed',
    filename: 'failed.pdf',
    status: DocumentStatus.failed,
    createdAt: DateTime(2026, 8, 17));
