import 'package:flutter/material.dart';

import '../domain/document.dart';
import 'document_formatters.dart';

class DocumentDetailSheet extends StatelessWidget {
  const DocumentDetailSheet({
    super.key,
    required this.document,
    required this.isRetrying,
    required this.isDeleting,
    required this.onRetry,
    required this.onDelete,
  });

  final Document document;
  final bool isRetrying;
  final bool isDeleting;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD7D9E2),
                          borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 22),
              Text(document.filename,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _Metadata(label: 'Status', value: _statusLabel(document.status)),
              _Metadata(
                  label: 'Created',
                  value: formatDocumentDate(document.createdAt,
                      includeTime: true)),
              if (document.updatedAt != null)
                _Metadata(
                    label: 'Updated',
                    value: formatDocumentDate(document.updatedAt!,
                        includeTime: true)),
              if (document.fileSize != null)
                _Metadata(
                    label: 'File size',
                    value: formatFileSize(document.fileSize!)),
              if (document.chunkCount != null)
                _Metadata(label: 'Chunks', value: '${document.chunkCount}'),
              if (document.mimeType != null)
                _Metadata(label: 'Type', value: document.mimeType!),
              const SizedBox(height: 18),
              Row(children: [
                if (document.status == DocumentStatus.failed) ...[
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: isRetrying ? null : onRetry,
                          icon: isRetrying
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          label: Text(isRetrying ? 'Processing' : 'Retry'))),
                  const SizedBox(width: 12),
                ],
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: isDeleting ? null : onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(isDeleting ? 'Deleting…' : 'Delete'))),
              ]),
            ]),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF6E7383)))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
      );
}

String _statusLabel(DocumentStatus status) => switch (status) {
      DocumentStatus.processing => 'Processing',
      DocumentStatus.ready => 'Ready',
      DocumentStatus.failed => 'Failed',
    };
