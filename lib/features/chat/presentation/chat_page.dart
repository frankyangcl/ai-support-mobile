import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/chat_message.dart';
import '../domain/citation.dart';
import 'chat_controller.dart';
import 'chat_state.dart';
import 'conversations_controller.dart';
import 'conversations_sheet.dart';
import '../../../core/observability/analytics_service.dart';
import '../../../core/observability/observability_providers.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatController _chatController;
  bool _followLatest = true;

  @override
  void initState() {
    super.initState();
    _chatController = ref.read(chatControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_updateFollowState);
  }

  @override
  void didChangeMetrics() {
    if (_followLatest) _scheduleScrollToBottom();
  }

  void _updateFollowState() {
    if (!_scrollController.hasClients) return;
    final nearBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset <
            100;
    if (nearBottom != _followLatest && mounted) {
      setState(() => _followLatest = nearBottom);
    }
  }

  void _scheduleScrollToBottom({bool force = false}) {
    if (!force && !_followLatest) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    setState(() => _followLatest = true);
    _scheduleScrollToBottom(force: true);
    await ref.read(chatControllerProvider.notifier).sendMessage(text);
  }

  Future<void> _copy(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  @override
  void dispose() {
    _chatController.stopGeneration();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_updateFollowState)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chat = ref.watch(chatControllerProvider);
    ref.watch(conversationsControllerProvider);
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      if (previous?.messages != next.messages) _scheduleScrollToBottom();
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
                colors: colors,
                onConversations: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const ConversationsSheet())),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  if (chat.isLoadingHistory)
                    const Center(child: CircularProgressIndicator())
                  else if (chat.historyError != null)
                    Center(child: Text(chat.historyError!))
                  else
                    ListView.builder(
                      key: const Key('chat-message-list'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                      itemCount: chat.messages.length,
                      itemBuilder: (context, index) {
                        final message = chat.messages[index];
                        return _MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          failureMessage:
                              message.status == ChatMessageStatus.failed
                                  ? chat.errorMessage
                                  : null,
                          onCopy: () => _copy(message.content),
                          onRetry: ref
                                  .read(chatControllerProvider.notifier)
                                  .canRetry(message.id)
                              ? () => ref
                                  .read(chatControllerProvider.notifier)
                                  .retryMessage(message.id)
                              : null,
                        );
                      },
                    ),
                  if (!_followLatest)
                    Positioned(
                      right: 18,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        key: const Key('jump-to-latest'),
                        onPressed: () {
                          setState(() => _followLatest = true);
                          _scheduleScrollToBottom(force: true);
                        },
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ),
                ],
              ),
            ),
            _Composer(
              controller: _textController,
              isGenerating: chat.isGenerating,
              onSend: _send,
              onStop: () =>
                  ref.read(chatControllerProvider.notifier).stopGeneration(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.colors, required this.onConversations});
  final ColorScheme colors;
  final VoidCallback onConversations;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome, size: 20, color: colors.onPrimary),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Support Agent',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Grounded answers with citations',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6E7383)),
                ),
              ],
            ),
          ),
          IconButton(
              key: const Key('conversations-launcher'),
              tooltip: 'Conversations',
              onPressed: onConversations,
              icon: const Icon(Icons.forum_outlined)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onCopy,
    this.onRetry,
    this.failureMessage,
    super.key,
  });

  final ChatMessage message;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;
  final String? failureMessage;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? colors.primary : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border:
                    isUser ? null : Border.all(color: const Color(0xFFE6E8F0)),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: colors.onPrimary,
                      ),
                    )
                  : _AssistantContent(message: message),
            ),
            if (message.citations.isNotEmpty)
              _CitationSection(citations: message.citations),
            if (!isUser)
              _ActionRow(
                message: message,
                failureMessage: failureMessage,
                onCopy: onCopy,
                onRetry: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

class _AssistantContent extends StatelessWidget {
  const _AssistantContent({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.content.isEmpty &&
        (message.status == ChatMessageStatus.sending ||
            message.status == ChatMessageStatus.streaming)) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 9),
          Text('Thinking...', style: TextStyle(color: Color(0xFF6E7383))),
        ],
      );
    }
    if (message.content.isEmpty && message.status == ChatMessageStatus.failed) {
      return const Text('Response failed');
    }
    return MarkdownBody(
      key: Key('markdown-${message.id}'),
      data: message.content,
      selectable: true,
      softLineBreak: true,
      onTapLink: (_, href, __) async {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, height: 1.45),
        code: const TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Color(0xFFF1F3FA),
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF1F3FA),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.message,
    required this.onCopy,
    this.onRetry,
    this.failureMessage,
  });
  final ChatMessage message;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;
  final String? failureMessage;

  @override
  Widget build(BuildContext context) {
    final completed = message.status == ChatMessageStatus.completed &&
        message.content.isNotEmpty;
    final failed = message.status == ChatMessageStatus.failed;
    final cancelled = message.status == ChatMessageStatus.cancelled;
    if (!completed && !failed && !cancelled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failed && failureMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(
                failureMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A3D3D)),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (completed)
                TextButton.icon(
                  key: Key('copy-${message.id}'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy'),
                ),
              if (failed && onRetry != null)
                TextButton.icon(
                  key: Key('retry-${message.id}'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('Retry'),
                ),
              if (cancelled)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    'Stopped',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6E7383)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CitationSection extends ConsumerWidget {
  const _CitationSection({required this.citations});
  final List<Citation> citations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(remoteSettingsProvider).maxVisibleCitations;
    final visible = citations.take(limit < 1 ? 1 : limit).toList();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxWidth: 350),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        key: const Key('citation-section'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: const Icon(
          Icons.description_outlined,
          size: 19,
          color: Color(0xFF4756B3),
        ),
        title: Text(
          'Sources (${citations.length})',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onExpansionChanged: (expanded) {
          if (expanded) {
            ref.read(analyticsServiceProvider).track('citation_opened');
          }
        },
        children: [
          for (var index = 0; index < visible.length; index++)
            _CitationCard(index: index + 1, citation: visible[index]),
        ],
      ),
    );
  }
}

class _CitationCard extends StatelessWidget {
  const _CitationCard({required this.index, required this.citation});
  final int index;
  final Citation citation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[$index] ${citation.filename}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4756B3),
            ),
          ),
          if (citation.chunkIndex != null) ...[
            const SizedBox(height: 4),
            Text(
              'Chunk ${citation.chunkIndex}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6E7383)),
            ),
          ],
          if (citation.preview != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Relevant excerpt:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              citation.preview!,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE6E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ask about your documents...',
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: isGenerating ? null : (_) => onSend(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 50,
              height: 50,
              child: isGenerating
                  ? IconButton.filled(
                      key: const Key('stop-generation'),
                      tooltip: 'Stop generation',
                      onPressed: onStop,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  : IconButton.filled(
                      key: const Key('send-message'),
                      tooltip: 'Send message',
                      onPressed: onSend,
                      icon: const Icon(Icons.send),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
