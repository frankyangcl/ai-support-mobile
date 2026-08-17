import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../data/remote_document_repository.dart';
import '../domain/document.dart';
import '../domain/document_repository.dart';
import 'document_file_picker.dart';
import 'documents_state.dart';
import '../../../core/observability/analytics_service.dart';
import '../../../core/observability/observability_providers.dart';
import '../../../core/observability/error_reporting_policy.dart';

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => RemoteDocumentRepository(ref.watch(apiClientProvider)),
);
final documentFilePickerProvider = Provider<DocumentFilePicker>(
  (_) => const SystemDocumentFilePicker(),
);
final documentsPollingIntervalProvider = Provider<Duration>(
  (_) => const Duration(seconds: 3),
);
final documentsControllerProvider =
    NotifierProvider.autoDispose<DocumentsController, DocumentsState>(
  DocumentsController.new,
);

class DocumentsController extends AutoDisposeNotifier<DocumentsState> {
  Timer? _pollTimer;
  bool _refreshing = false;
  int _pollCount = 0;
  static const _maximumPolls = 40;

  @override
  DocumentsState build() {
    ref.onDispose(_stopPolling);
    Future<void>.microtask(load);
    return const DocumentsState();
  }

  Future<void> load() async {
    state = state.copyWith(
      status: DocumentsLoadStatus.loading,
      clearLoadError: true,
    );
    await _fetchDocuments(showLoading: true);
  }

  Future<void> refresh() => _fetchDocuments(showLoading: false);

  Future<void> _fetchDocuments({required bool showLoading}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final documents =
          await ref.read(documentRepositoryProvider).listDocuments();
      state = state.copyWith(
        status: DocumentsLoadStatus.success,
        documents: documents,
        clearLoadError: true,
      );
      _syncPolling(documents);
    } catch (error, stack) {
      await reportIfUnexpected(ref.read(crashReporterProvider), error, stack, reason: 'Documents load');
      if (showLoading || state.status != DocumentsLoadStatus.success) {
        state =
            state.copyWith(status: DocumentsLoadStatus.error, loadError: error);
      } else {
        state = state.copyWith(actionError: messageForDocumentError(error));
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> chooseAndUpload() async {
    if (state.isAddingDocument) return false;
    state = state.copyWith(isChoosingFile: true, clearActionError: true);
    try {
      final picked = await ref.read(documentFilePickerProvider).pickPdf();
      if (picked == null) return false;
      await ref.read(analyticsServiceProvider).track('document_upload_started');
      state = state.copyWith(isChoosingFile: false, isUploading: true);
      final uploaded = await ref.read(documentRepositoryProvider).uploadPdf(
            filename: picked.filename,
            bytes: picked.bytes,
          );
      await ref.read(analyticsServiceProvider).track(
          'document_upload_completed',
          parameters: {'status': uploaded.status.name});
      await refresh();
      return true;
    } catch (error, stack) {
      await reportIfUnexpected(ref.read(crashReporterProvider), error, stack, reason: 'Document upload');
      await ref.read(analyticsServiceProvider).track('document_upload_failed');
      state = state.copyWith(actionError: messageForDocumentError(error));
      return false;
    } finally {
      state = state.copyWith(isChoosingFile: false, isUploading: false);
    }
  }

  Future<bool> retryDocument(String id) async {
    if (state.retryingIds.contains(id)) return false;
    state = state.copyWith(
      retryingIds: {...state.retryingIds, id},
      clearActionError: true,
    );
    try {
      final document =
          await ref.read(documentRepositoryProvider).retryDocument(id);
      _replace(document);
      await refresh();
      return true;
    } catch (error, stack) {
      await reportIfUnexpected(ref.read(crashReporterProvider), error, stack, reason: 'Document retry');
      state = state.copyWith(actionError: messageForDocumentError(error));
      return false;
    } finally {
      state = state.copyWith(retryingIds: {...state.retryingIds}..remove(id));
    }
  }

  Future<bool> deleteDocument(String id) async {
    if (state.deletingIds.contains(id)) return false;
    state = state.copyWith(
      deletingIds: {...state.deletingIds, id},
      clearActionError: true,
    );
    try {
      await ref.read(documentRepositoryProvider).deleteDocument(id);
      await ref.read(analyticsServiceProvider).track('document_deleted');
      final remaining = state.documents.where((item) => item.id != id).toList();
      state = state.copyWith(documents: remaining);
      _syncPolling(remaining);
      return true;
    } catch (error, stack) {
      await reportIfUnexpected(ref.read(crashReporterProvider), error, stack, reason: 'Document delete');
      state = state.copyWith(actionError: messageForDocumentError(error));
      return false;
    } finally {
      state = state.copyWith(deletingIds: {...state.deletingIds}..remove(id));
    }
  }

  void clearActionError() => state = state.copyWith(clearActionError: true);

  void _replace(Document document) {
    state = state.copyWith(documents: [
      for (final current in state.documents)
        if (current.id == document.id) document else current,
    ]);
  }

  void _syncPolling(List<Document> documents) {
    if (!documents.any((item) => item.status == DocumentStatus.processing)) {
      _stopPolling();
      return;
    }
    if (_pollTimer != null) return;
    _pollCount = 0;
    _pollTimer =
        Timer.periodic(ref.read(documentsPollingIntervalProvider), (_) {
      _pollCount += 1;
      if (_pollCount > _maximumPolls) {
        _stopPolling();
      } else {
        refresh();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollCount = 0;
  }
}

String messageForDocumentError(Object? error, {bool loading = false}) {
  if (error is FilePickerException) return error.message;
  if (error is ApiException) {
    if (error.statusCode == 401) return 'Authentication expired.';
    if (error.statusCode == 409) return 'Document is still processing.';
    if (error.statusCode == 413) return 'The PDF is too large to upload.';
    if (error.type == ApiErrorType.network ||
        error.type == ApiErrorType.timeout) {
      return loading
          ? 'Unable to connect.'
          : 'Unable to connect. Please try again.';
    }
  }
  return loading
      ? 'Unable to load documents.'
      : 'Unable to complete the document action.';
}
