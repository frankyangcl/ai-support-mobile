import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/presentation/chat_page.dart';
import '../domain/document.dart';
import 'documents_controller.dart';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final documents = ref.watch(documentsControllerProvider);
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.auto_awesome, color: colors.onPrimary),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Support',
                          style: TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('RAG-powered knowledge assistant',
                          style: TextStyle(
                              color: Color(0xFF6E7383), fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EF),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Color(0xFF23945A)),
                      SizedBox(width: 6),
                      Text('Ready',
                          style: TextStyle(
                              color: Color(0xFF23784C),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            if (auth.session != null) ...[
              const SizedBox(height: 18),
              _UserSummary(
                name: auth.session!.user.displayName,
                email: auth.session!.user.email,
                pictureUrl: auth.session!.user.pictureUrl,
                onLogout: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
            const SizedBox(height: 42),
            const Text(
              'Instant answers from\ntrusted company knowledge.',
              style: TextStyle(
                  fontSize: 30,
                  height: 1.18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ask questions and receive grounded answers with source citations.',
              style: TextStyle(
                  fontSize: 15, height: 1.5, color: Color(0xFF6E7383)),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ChatPage()),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Start Conversation',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              children: [
                const Text('Knowledge Base',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (documents.hasValue)
                  _CountBadge(count: documents.value!.length),
              ],
            ),
            const SizedBox(height: 16),
            documents.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => ErrorState(
                onRetry: () =>
                    ref.read(documentsControllerProvider.notifier).retry(),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                          child: Text('No documents available.',
                              style: TextStyle(color: Color(0xFF6E7383)))),
                    )
                  : Column(children: [
                      for (final item in items) _DocumentCard(document: item)
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSummary extends StatelessWidget {
  const _UserSummary({
    required this.name,
    required this.email,
    required this.pictureUrl,
    required this.onLogout,
  });

  final String name;
  final String? email;
  final Uri? pictureUrl;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage:
              pictureUrl == null ? null : NetworkImage(pictureUrl.toString()),
          child: pictureUrl == null ? const Icon(Icons.person_outline) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (email != null)
                Text(email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6E7383))),
            ],
          ),
        ),
        TextButton(onPressed: onLogout, child: const Text('Logout')),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFEDEFF7),
          borderRadius: BorderRadius.circular(20)),
      child: Text('$count documents',
          style: const TextStyle(
              color: Color(0xFF5D6272),
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: const Color(0xFFF0F2FA),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.picture_as_pdf_outlined,
                color: Color(0xFF4756B3)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.filename,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 15, color: Color(0xFF23945A)),
                    SizedBox(width: 5),
                    Text('Ready',
                        style: TextStyle(
                            color: Color(0xFF23784C),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
