import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/chat_message.dart';
import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    await ref.read(chatControllerProvider.notifier).sendMessage(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chat = ref.watch(chatControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back)),
                  const SizedBox(width: 4),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.auto_awesome,
                        size: 20, color: colors.onPrimary),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Support Agent',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Grounded answers with citations',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF6E7383))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                itemCount: chat.messages.length + (chat.isRequesting ? 1 : 0),
                itemBuilder: (context, index) {
                  if (chat.isRequesting && index == chat.messages.length) {
                    return const Align(
                        alignment: Alignment.centerLeft,
                        child: _ThinkingBubble());
                  }
                  return _MessageBubble(message: chat.messages[index]);
                },
              ),
            ),
            Container(
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
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !chat.isRequesting,
                        decoration: InputDecoration(
                          hintText: chat.isRequesting
                              ? 'Waiting for response...'
                              : 'Ask about your documents...',
                          filled: true,
                          fillColor: const Color(0xFFF7F8FC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none),
                        ),
                        onSubmitted: chat.isRequesting ? null : (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: IconButton.filled(
                        onPressed: chat.isRequesting ? null : _send,
                        icon: chat.isRequesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: const BoxConstraints(maxWidth: 330),
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
              child: Text(
                message.content,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: isUser ? colors.onPrimary : colors.onSurface),
              ),
            ),
            for (final citation in message.citations)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F3FA),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 17, color: Color(0xFF4756B3)),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(citation.filename,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4756B3))),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 9),
          Text('Thinking...',
              style: TextStyle(fontSize: 13, color: Color(0xFF6E7383))),
        ],
      ),
    );
  }
}
