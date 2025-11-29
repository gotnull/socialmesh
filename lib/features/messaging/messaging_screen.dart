import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';

/// Conversation type enum
enum ConversationType { channel, directMessage }

/// Main messaging screen - shows list of conversations
class MessagingScreen extends ConsumerWidget {
  const MessagingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final nodes = ref.watch(nodesProvider);
    final messages = ref.watch(messagesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Build conversation list: channels first, then DM threads
    final List<_Conversation> conversations = [];

    // Add channel conversations
    for (final channel in channels) {
      final channelMessages = messages
          .where((m) => m.channel == channel.index && m.isBroadcast)
          .toList();
      final lastMessage = channelMessages.isNotEmpty
          ? channelMessages.last
          : null;
      final unreadCount = channelMessages
          .where((m) => m.received && m.from != myNodeNum)
          .length;

      conversations.add(
        _Conversation(
          type: ConversationType.channel,
          channelIndex: channel.index,
          name: channel.name.isEmpty
              ? (channel.index == 0
                    ? 'Primary Channel'
                    : 'Channel ${channel.index}')
              : channel.name,
          lastMessage: lastMessage?.text,
          lastMessageTime: lastMessage?.timestamp,
          unreadCount: unreadCount,
          isEncrypted: channel.psk.isNotEmpty,
        ),
      );
    }

    // Add DM conversations (group messages by node)
    final dmNodes = <int>{};
    for (final message in messages) {
      if (message.isDirect) {
        final otherNode = message.from == myNodeNum ? message.to : message.from;
        dmNodes.add(otherNode);
      }
    }

    for (final nodeNum in dmNodes) {
      final node = nodes[nodeNum];
      final nodeMessages = messages
          .where((m) => m.isDirect && (m.from == nodeNum || m.to == nodeNum))
          .toList();
      final lastMessage = nodeMessages.isNotEmpty ? nodeMessages.last : null;
      final unreadCount = nodeMessages
          .where((m) => m.received && m.from == nodeNum)
          .length;

      conversations.add(
        _Conversation(
          type: ConversationType.directMessage,
          nodeNum: nodeNum,
          name: node?.displayName ?? 'Node ${nodeNum.toRadixString(16)}',
          shortName: node?.shortName,
          avatarColor: node?.avatarColor,
          lastMessage: lastMessage?.text,
          lastMessageTime: lastMessage?.timestamp,
          unreadCount: unreadCount,
        ),
      );
    }

    // Sort by last message time
    conversations.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.white),
            onPressed: () => _showNewMessageSheet(context, ref),
          ),
        ],
      ),
      body: conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 40,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a new message',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return _ConversationTile(
                  conversation: conv,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          type: conv.type,
                          channelIndex: conv.channelIndex,
                          nodeNum: conv.nodeNum,
                          title: conv.name,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showNewMessageSheet(BuildContext context, WidgetRef ref) {
    final channels = ref.read(channelsProvider);
    final nodes = ref.read(nodesProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'New Message',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Container(
              height: 1,
              color: AppTheme.darkBorder.withValues(alpha: 0.3),
            ),

            // Channels section
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'CHANNELS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                  fontFamily: 'Inter',
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (final channel in channels)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    channel.psk.isNotEmpty ? Icons.lock : Icons.tag,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                title: Text(
                  channel.name.isEmpty
                      ? (channel.index == 0
                            ? 'Primary Channel'
                            : 'Channel ${channel.index}')
                      : channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        type: ConversationType.channel,
                        channelIndex: channel.index,
                        title: channel.name.isEmpty
                            ? (channel.index == 0
                                  ? 'Primary Channel'
                                  : 'Channel ${channel.index}')
                            : channel.name,
                      ),
                    ),
                  );
                },
              ),

            // Direct messages section
            if (nodes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'DIRECT MESSAGE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                    fontFamily: 'Inter',
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              for (final node in nodes.values.take(5))
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: node.avatarColor != null
                          ? Color(node.avatarColor!)
                          : AppTheme.graphPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        node.shortName ??
                            node.nodeNum.toRadixString(16).substring(0, 2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    node.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          type: ConversationType.directMessage,
                          nodeNum: node.nodeNum,
                          title: node.displayName,
                        ),
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Conversation {
  final ConversationType type;
  final int? channelIndex;
  final int? nodeNum;
  final String name;
  final String? shortName;
  final int? avatarColor;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isEncrypted;

  _Conversation({
    required this.type,
    this.channelIndex,
    this.nodeNum,
    required this.name,
    this.shortName,
    this.avatarColor,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isEncrypted = false,
  });
}

class _ConversationTile extends StatelessWidget {
  final _Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final isChannel = conversation.type == ConversationType.channel;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isChannel
                        ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                        : (conversation.avatarColor != null
                              ? Color(conversation.avatarColor!)
                              : AppTheme.graphPurple),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isChannel
                        ? Icon(
                            conversation.isEncrypted ? Icons.lock : Icons.tag,
                            color: AppTheme.primaryGreen,
                            size: 24,
                          )
                        : Text(
                            conversation.shortName ??
                                conversation.name.substring(0, 2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.lastMessageTime != null)
                            Text(
                              timeFormat.format(conversation.lastMessageTime!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                                fontFamily: 'Inter',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage ??
                                  (isChannel
                                      ? 'No messages'
                                      : 'Start a conversation'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${conversation.unreadCount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chat screen - shows messages for a specific channel or DM
class ChatScreen extends ConsumerStatefulWidget {
  final ConversationType type;
  final int? channelIndex;
  final int? nodeNum;
  final String title;

  const ChatScreen({
    super.key,
    required this.type,
    this.channelIndex,
    this.nodeNum,
    required this.title,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final myNodeNum = ref.read(myNodeNumProvider);
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create pending message
    final pendingMessage = Message(
      id: messageId,
      from: myNodeNum ?? 0,
      to: widget.type == ConversationType.channel
          ? 0xFFFFFFFF
          : widget.nodeNum!,
      text: text,
      channel: widget.type == ConversationType.channel
          ? widget.channelIndex ?? 0
          : 0,
      sent: true,
      status: MessageStatus.pending,
    );

    // Add to messages immediately for optimistic UI
    ref.read(messagesProvider.notifier).addMessage(pendingMessage);
    _messageController.clear();

    try {
      final protocol = ref.read(protocolServiceProvider);

      if (widget.type == ConversationType.channel) {
        await protocol.sendMessage(
          text: text,
          to: 0xFFFFFFFF, // Broadcast to channel
          channel: widget.channelIndex ?? 0,
          wantAck: false,
        );
      } else {
        await protocol.sendMessage(
          text: text,
          to: widget.nodeNum!,
          channel: 0,
          wantAck: true,
        );
      }

      // Update status to sent
      ref
          .read(messagesProvider.notifier)
          .updateMessage(
            messageId,
            pendingMessage.copyWith(status: MessageStatus.sent),
          );
    } catch (e) {
      // Update status to failed with error
      ref
          .read(messagesProvider.notifier)
          .updateMessage(
            messageId,
            pendingMessage.copyWith(
              status: MessageStatus.failed,
              errorMessage: e.toString(),
            ),
          );
    }
  }

  Future<void> _retryMessage(Message message) async {
    // Update to pending
    ref
        .read(messagesProvider.notifier)
        .updateMessage(
          message.id,
          message.copyWith(status: MessageStatus.pending, errorMessage: null),
        );

    try {
      final protocol = ref.read(protocolServiceProvider);

      if (message.isBroadcast) {
        await protocol.sendMessage(
          text: message.text,
          to: 0xFFFFFFFF,
          channel: message.channel ?? 0,
          wantAck: false,
        );
      } else {
        await protocol.sendMessage(
          text: message.text,
          to: message.to,
          channel: 0,
          wantAck: true,
        );
      }

      ref
          .read(messagesProvider.notifier)
          .updateMessage(
            message.id,
            message.copyWith(status: MessageStatus.sent, errorMessage: null),
          );
    } catch (e) {
      ref
          .read(messagesProvider.notifier)
          .updateMessage(
            message.id,
            message.copyWith(
              status: MessageStatus.failed,
              errorMessage: e.toString(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Filter messages for this conversation
    List<Message> filteredMessages;
    if (widget.type == ConversationType.channel) {
      filteredMessages = messages
          .where((m) => m.channel == widget.channelIndex && m.isBroadcast)
          .toList();
    } else {
      filteredMessages = messages
          .where(
            (m) =>
                m.isDirect &&
                (m.from == widget.nodeNum || m.to == widget.nodeNum),
          )
          .toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.type == ConversationType.channel
                    ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                    : AppTheme.graphPurple,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: widget.type == ConversationType.channel
                    ? const Icon(
                        Icons.tag,
                        color: AppTheme.primaryGreen,
                        size: 18,
                      )
                    : Text(
                        widget.title.substring(0, 2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    widget.type == ConversationType.channel
                        ? 'Channel'
                        : 'Direct Message',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: filteredMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.type == ConversationType.channel
                              ? 'No messages in this channel'
                              : 'Start the conversation',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, index) {
                      final message =
                          filteredMessages[filteredMessages.length - 1 - index];
                      final isFromMe = message.from == myNodeNum;
                      final senderNode = nodes[message.from];

                      return _MessageBubble(
                        message: message,
                        isFromMe: isFromMe,
                        senderName: senderNode?.displayName ?? 'Unknown',
                        senderShortName:
                            senderNode?.shortName ??
                            message.from
                                .toRadixString(16)
                                .padLeft(4, '0')
                                .substring(0, 4),
                        avatarColor: senderNode?.avatarColor,
                        showSender:
                            widget.type == ConversationType.channel &&
                            !isFromMe,
                        onRetry: message.isFailed
                            ? () => _retryMessage(message)
                            : null,
                      );
                    },
                  ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              border: Border(
                top: BorderSide(
                  color: AppTheme.darkBorder.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: AppTheme.textTertiary,
                            fontFamily: 'Inter',
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isFromMe;
  final String senderName;
  final String senderShortName;
  final int? avatarColor;
  final bool showSender;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.isFromMe,
    required this.senderName,
    required this.senderShortName,
    this.avatarColor,
    this.showSender = true,
    this.onRetry,
  });

  Color _getAvatarColor() {
    if (avatarColor != null) return Color(avatarColor!);
    final colors = [
      const Color(0xFF5B4FCE),
      const Color(0xFFD946A6),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
    ];
    return colors[message.from % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final isFailed = message.isFailed;
    final isPending = message.isPending;

    if (isFromMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isFailed
                          ? AppTheme.errorRed.withValues(alpha: 0.8)
                          : isPending
                          ? AppTheme.primaryGreen.withValues(alpha: 0.6)
                          : AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          message.text,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPending) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              timeFormat.format(message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isFailed) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.errorMessage ?? 'Failed to send',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.errorRed,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 12,
                                color: AppTheme.primaryGreen,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
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
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showSender)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _getAvatarColor(),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  senderShortName.length > 4
                      ? senderShortName.substring(0, 4)
                      : senderShortName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          Flexible(
            child: Container(
              margin: EdgeInsets.only(right: 64, left: showSender ? 0 : 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSender) ...[
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getAvatarColor(),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeFormat.format(message.timestamp),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
