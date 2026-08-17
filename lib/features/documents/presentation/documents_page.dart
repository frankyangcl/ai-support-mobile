import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../chat/presentation/chat_page.dart';
import '../domain/document.dart';
import 'document_detail_sheet.dart';
import 'documents_controller.dart';
import 'documents_state.dart';
import '../../../core/observability/observability_providers.dart';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentsControllerProvider);
    final controller = ref.read(documentsControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);
    final remote = ref.watch(remoteSettingsProvider);
    ref.listen(documentsControllerProvider, (previous, next) {
      if (next.actionError != null &&
          next.actionError != previous?.actionError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.actionError!)));
        controller.clearActionError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
            children: [
              _Header(
                  onLogout: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  name: auth.session?.user.displayName,
                  email: auth.session?.user.email,
                  pictureUrl: auth.session?.user.pictureUrl),
              const SizedBox(height: 42),
              const Text('Instant answers from\ntrusted company knowledge.',
                  style: TextStyle(
                      fontSize: 30,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6)),
              const SizedBox(height: 14),
              const Text(
                  'Ask questions and receive grounded answers with source citations.',
                  style: TextStyle(
                      fontSize: 15, height: 1.5, color: Color(0xFF6E7383))),
              const SizedBox(height: 28),
              if (remote.maintenanceBanner.isNotEmpty) ...[
                Semantics(
                    liveRegion: true,
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D6),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(remote.maintenanceBanner))),
                const SizedBox(height: 14),
              ],
              SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                      onPressed: () {
                        if (!remote.chatFeatureEnabled) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Chat is temporarily unavailable.')));
                          return;
                        }
                        Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => const ChatPage()));
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Start Conversation',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))))),
              const SizedBox(height: 44),
              Row(children: [
                const Expanded(
                    child: Text('Knowledge Base',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w700))),
                TextButton.icon(
                  onPressed: state.isAddingDocument
                      ? null
                      : () => controller.chooseAndUpload(),
                  icon: state.isAddingDocument
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add),
                  label:
                      Text(state.isUploading ? 'Uploading…' : 'Add document'),
                ),
              ]),
              if (state.status == DocumentsLoadStatus.success) ...[
                const Text('Ready documents are available to AI Support.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6E7383))),
                const SizedBox(height: 14),
              ],
              _DocumentsContent(state: state, controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentsContent extends StatelessWidget {
  const _DocumentsContent({required this.state, required this.controller});
  final DocumentsState state;
  final DocumentsController controller;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case DocumentsLoadStatus.loading:
        return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()));
      case DocumentsLoadStatus.error:
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 38, color: Color(0xFF6E7383)),
              const SizedBox(height: 10),
              Text(messageForDocumentError(state.loadError, loading: true),
                  style: const TextStyle(color: Color(0xFF6E7383))),
              const SizedBox(height: 10),
              OutlinedButton(
                  onPressed: controller.load, child: const Text('Retry')),
            ]));
      case DocumentsLoadStatus.success:
        if (state.documents.isEmpty) {
          return _EmptyState(
              onAdd:
                  state.isAddingDocument ? null : controller.chooseAndUpload);
        }
        return Column(children: [
          for (final document in state.documents)
            _DocumentCard(
                document: document,
                isRetrying: state.retryingIds.contains(document.id),
                isDeleting: state.deletingIds.contains(document.id),
                controller: controller)
        ]);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6E8F0))),
        child: Column(children: [
          const Icon(Icons.library_add_outlined,
              size: 40, color: Color(0xFF4756B3)),
          const SizedBox(height: 12),
          const Text('No documents yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Upload a PDF to build your knowledge base.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6E7383))),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add document'))
        ]),
      );
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard(
      {required this.document,
      required this.isRetrying,
      required this.isDeleting,
      required this.controller});
  final Document document;
  final bool isRetrying;
  final bool isDeleting;
  final DocumentsController controller;

  @override
  Widget build(BuildContext context) {
    final canOpen = document.status != DocumentStatus.processing;
    return InkWell(
      key: ValueKey('document-${document.id}'),
      onTap: canOpen ? () => _showDetail(context) : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6E8F0))),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F2FA),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.picture_as_pdf_outlined,
                  color: Color(0xFF4756B3))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(document.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _Status(document: document, processing: isRetrying),
              ])),
          if (document.status == DocumentStatus.failed)
            IconButton(
                tooltip: 'Retry',
                onPressed: isRetrying
                    ? null
                    : () => controller.retryDocument(document.id),
                icon: isRetrying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh)),
          if (canOpen)
            const Icon(Icons.chevron_right, color: Color(0xFF9A9EAC)),
        ]),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        builder: (sheetContext) => DocumentDetailSheet(
          document: document,
          isRetrying: isRetrying,
          isDeleting: isDeleting,
          onRetry: () {
            Navigator.pop(sheetContext);
            controller.retryDocument(document.id);
          },
          onDelete: () async {
            Navigator.pop(sheetContext);
            if (await _confirmDelete(context, document.filename)) {
              final deleted = await controller.deleteDocument(document.id);
              if (deleted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document deleted')));
              }
            }
          },
        ),
      );
}

class _Status extends StatelessWidget {
  const _Status({required this.document, required this.processing});
  final Document document;
  final bool processing;
  @override
  Widget build(BuildContext context) {
    final status = processing ? DocumentStatus.processing : document.status;
    final (label, color, icon) = switch (status) {
      DocumentStatus.processing => (
          'Processing',
          const Color(0xFF8B6B16),
          Icons.sync
        ),
      DocumentStatus.ready => (
          'Ready',
          const Color(0xFF23784C),
          Icons.check_circle
        ),
      DocumentStatus.failed => (
          'Failed',
          const Color(0xFFB23A48),
          Icons.error_outline
        ),
    };
    final extra = status == DocumentStatus.ready && document.chunkCount != null
        ? ' · ${document.chunkCount} chunks'
        : '';
    return Row(children: [
      if (status == DocumentStatus.processing)
        SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color))
      else
        Icon(icon, size: 15, color: color),
      const SizedBox(width: 5),
      Text('$label$extra',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w500))
    ]);
  }
}

Future<bool> _confirmDelete(BuildContext context, String filename) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Delete "$filename"?'),
                content: const Text(
                    'This will remove the document from the knowledge base.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'))
                ])) ??
    false;

class _Header extends StatelessWidget {
  const _Header(
      {required this.onLogout, this.name, this.email, this.pictureUrl});
  final VoidCallback onLogout;
  final String? name;
  final String? email;
  final Uri? pictureUrl;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(children: [
      Row(children: [
        Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: colors.primary, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.auto_awesome, color: colors.onPrimary)),
        const SizedBox(width: 14),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI Support',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text('RAG-powered knowledge assistant',
              style: TextStyle(color: Color(0xFF6E7383), fontSize: 13))
        ]))
      ]),
      if (name != null) ...[
        const SizedBox(height: 18),
        Row(children: [
          CircleAvatar(
              radius: 20,
              backgroundImage: pictureUrl == null
                  ? null
                  : NetworkImage(pictureUrl.toString()),
              child:
                  pictureUrl == null ? const Icon(Icons.person_outline) : null),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (email != null)
                  Text(email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6E7383)))
              ])),
          TextButton(onPressed: onLogout, child: const Text('Logout'))
        ])
      ]
    ]);
  }
}
