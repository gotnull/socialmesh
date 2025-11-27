import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';

class MessagingScreen extends ConsumerStatefulWidget {
  const MessagingScreen({super.key});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  int _selectedNodeNum = 0xFFFFFFFF; // Broadcast by default

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.sendMessage(
        text: text,
        to: _selectedNodeNum,
        wantAck: _selectedNodeNum != 0xFFFFFFFF,
      );

      _messageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message sent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Filter messages for selected node (or all for broadcast)
    final filteredMessages = _selectedNodeNum == 0xFFFFFFFF
        ? messages
        : messages
              .where(
                (m) =>
                    (m.from == _selectedNodeNum || m.to == _selectedNodeNum) ||
                    (m.from == myNodeNum || m.to == myNodeNum),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.person),
            tooltip: 'Select recipient',
            onSelected: (nodeNum) {
              setState(() {
                _selectedNodeNum = nodeNum;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0xFFFFFFFF,
                child: ListTile(
                  leading: Icon(Icons.public),
                  title: Text('Broadcast'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              ...nodes.values.map(
                (node) => PopupMenuItem(
                  value: node.nodeNum,
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(node.displayName),
                    subtitle: Text('Node ${node.nodeNum}'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Selected recipient indicator
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  _selectedNodeNum == 0xFFFFFFFF ? Icons.public : Icons.person,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'To: ${_getRecipientName(_selectedNodeNum, nodes)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),

          // Message list
          Expanded(
            child: filteredMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message,
                          size: 64,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        const Text('No messages yet'),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, index) {
                      // Reverse order so newest is at bottom
                      final message =
                          filteredMessages[filteredMessages.length - 1 - index];
                      final isFromMe = message.from == myNodeNum;

                      return _MessageBubble(
                        message: message,
                        isFromMe: isFromMe,
                        senderName:
                            nodes[message.from]?.displayName ??
                            'Node ${message.from}',
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRecipientName(int nodeNum, Map<int, MeshNode> nodes) {
    if (nodeNum == 0xFFFFFFFF) return 'Broadcast';
    return nodes[nodeNum]?.displayName ?? 'Node $nodeNum';
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isFromMe;
  final String senderName;

  const _MessageBubble({
    required this.message,
    required this.isFromMe,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isFromMe
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromMe)
              Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            if (!isFromMe) const SizedBox(height: 4),
            Text(message.text),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeFormat.format(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (isFromMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.acked
                        ? Icons.done_all
                        : message.sent
                        ? Icons.done
                        : Icons.schedule,
                    size: 14,
                    color: message.acked ? Colors.blue : null,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
