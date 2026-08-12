import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'content': 'Hi! Ask me anything about your company documents.',
      'sources': <String>[],
    },
  ];

  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
        'sources': <String>[],
      });

      _isLoading = true;
    });

    _controller.clear();

    try {
      final data = await ApiService.askQuestion(text);

      final answer = data['answer']?.toString() ?? 'No answer returned.';

      final rawSources = data['sources'];

      final filenames = <String>[];

      if (rawSources is List) {
        for (final source in rawSources) {
          if (source is Map) {
            final filename = source['filename']?.toString();

            if (filename != null &&
                filename.isNotEmpty &&
                !filenames.contains(filename)) {
              filenames.add(filename);
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': answer,
          'sources': filenames,
        });

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Unable to get an answer right now. Please try again.',
          'sources': <String>[],
        });

        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                    child: Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: colors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Support Agent',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Grounded answers with citations',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6E7383),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  22,
                  20,
                  16,
                ),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isLoading && index == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _ThinkingBubble(),
                      ),
                    );
                  }

                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  final content = message['content']?.toString() ?? '';

                  final sources =
                      (message['sources'] as List<dynamic>).cast<String>();

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      constraints: const BoxConstraints(
                        maxWidth: 330,
                      ),
                      child: Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isUser ? colors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: isUser
                                  ? null
                                  : Border.all(
                                      color: const Color(
                                        0xFFE6E8F0,
                                      ),
                                    ),
                            ),
                            child: Text(
                              content,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.45,
                                color: isUser
                                    ? colors.onPrimary
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                          if (sources.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...sources.map(
                              (filename) => Container(
                                margin: const EdgeInsets.only(
                                  bottom: 6,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF1F3FA,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 17,
                                      color: Color(
                                        0xFF4756B3,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        filename,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(
                                            0xFF4756B3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                14,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE6E8F0),
                  ),
                ),
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
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: _isLoading
                              ? 'Waiting for response...'
                              : 'Ask about your documents...',
                          filled: true,
                          fillColor: const Color(0xFFF7F8FC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: _isLoading ? null : (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: IconButton.filled(
                        onPressed: _isLoading ? null : _sendMessage,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
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

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6E8F0),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 9),
          Text(
            'Thinking...',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6E7383),
            ),
          ),
        ],
      ),
    );
  }
}
