import '../domain/document.dart';

enum DocumentsLoadStatus { loading, success, error }

class DocumentsState {
  const DocumentsState({
    this.status = DocumentsLoadStatus.loading,
    this.documents = const [],
    this.loadError,
    this.actionError,
    this.isChoosingFile = false,
    this.isUploading = false,
    this.retryingIds = const {},
    this.deletingIds = const {},
  });

  final DocumentsLoadStatus status;
  final List<Document> documents;
  final Object? loadError;
  final String? actionError;
  final bool isChoosingFile;
  final bool isUploading;
  final Set<String> retryingIds;
  final Set<String> deletingIds;
  bool get isAddingDocument => isChoosingFile || isUploading;

  DocumentsState copyWith({
    DocumentsLoadStatus? status,
    List<Document>? documents,
    Object? loadError,
    bool clearLoadError = false,
    String? actionError,
    bool clearActionError = false,
    bool? isChoosingFile,
    bool? isUploading,
    Set<String>? retryingIds,
    Set<String>? deletingIds,
  }) =>
      DocumentsState(
        status: status ?? this.status,
        documents: documents ?? this.documents,
        loadError: clearLoadError ? null : loadError ?? this.loadError,
        actionError: clearActionError ? null : actionError ?? this.actionError,
        isChoosingFile: isChoosingFile ?? this.isChoosingFile,
        isUploading: isUploading ?? this.isUploading,
        retryingIds: retryingIds ?? this.retryingIds,
        deletingIds: deletingIds ?? this.deletingIds,
      );
}
