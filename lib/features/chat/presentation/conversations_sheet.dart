import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/conversation.dart';
import 'chat_controller.dart';
import 'conversations_controller.dart';
import 'conversations_state.dart';

class ConversationsSheet extends ConsumerWidget {
  const ConversationsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsControllerProvider);
    ref.listen(conversationsControllerProvider, (previous, next) {
      if (next.actionError != null &&
          next.actionError != previous?.actionError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.actionError!)));
        ref.read(conversationsControllerProvider.notifier).clearActionError();
      }
    });
    return SafeArea(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFD7D9E2),
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(
              child: Text('Conversations',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700))),
          FilledButton.icon(
              key: const Key('new-chat'),
              onPressed: () async {
                await ref.read(chatControllerProvider.notifier).newChat();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('New chat'))
        ]),
        const SizedBox(height: 12),
        Flexible(child: _Content(state: state)),
      ]),
    ));
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.state});
  final ConversationsState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.status) {
      case ConversationListStatus.loading:
        return const Padding(
            padding: EdgeInsets.all(30), child: CircularProgressIndicator());
      case ConversationListStatus.error:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text(conversationErrorMessage(state.error)),
          OutlinedButton(
              onPressed:
                  ref.read(conversationsControllerProvider.notifier).load,
              child: const Text('Retry'))
        ]);
      case ConversationListStatus.success:
        if (state.items.isEmpty) {
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                Icon(Icons.forum_outlined, size: 38, color: Color(0xFF4756B3)),
                SizedBox(height: 10),
                Text('No conversations yet',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 5),
                Text('Start a conversation with AI Support.',
                    style: TextStyle(color: Color(0xFF6E7383)))
              ]));
        }
        return ListView(shrinkWrap: true, children: [
          for (final item in state.items)
            _ConversationTile(item: item, active: state.activeId == item.id)
        ]);
    }
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.item, required this.active});
  final Conversation item;
  final bool active;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        key: ValueKey('conversation-${item.id}'),
        selected: active,
        selectedTileColor: const Color(0xFFEDEFFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.chat_bubble_outline),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle:
            Text('${_months[item.updatedAt.month - 1]} ${item.updatedAt.day}'),
        onTap: () async {
          Navigator.pop(context);
          await ref
              .read(chatControllerProvider.notifier)
              .loadConversation(item.id);
        },
        trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') _rename(context, ref);
              if (value == 'delete') _delete(context, ref);
            },
            itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete'))
                ]),
      );

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: item.title);
    final title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Rename conversation'),
                content: TextField(
                    key: const Key('rename-input'),
                    controller: controller,
                    autofocus: true),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Save'))
                ]));
    controller.dispose();
    if (title != null && title.isNotEmpty) {
      await ref
          .read(conversationsControllerProvider.notifier)
          .rename(item.id, title);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text('Delete "${item.title}"?'),
                    content: const Text(
                        'This will permanently delete this conversation and its messages.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'))
                    ])) ??
        false;
    if (!confirmed) return;
    final wasActive =
        ref.read(conversationsControllerProvider).activeId == item.id;
    final deleted = await ref
        .read(conversationsControllerProvider.notifier)
        .delete(item.id);
    if (deleted && wasActive) {
      await ref.read(chatControllerProvider.notifier).newChat();
    }
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
