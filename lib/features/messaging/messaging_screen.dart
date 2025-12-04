import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../models/canned_response.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/animated_list_item.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../services/messaging/offline_queue_service.dart';
import '../channels/channel_form_screen.dart';

/// Conversation type enum
enum ConversationType { channel, directMessage }

/// Main messaging screen - shows list of conversations
class MessagingScreen extends ConsumerWidget {
  const MessagingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final messages = ref.watch(messagesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Build DM conversations only (group messages by node)
    final List<_Conversation> conversations = [];
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
                      
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a new message',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                      
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return AnimatedListItem(
                  index: index,
                  child: _ConversationTile(
                    conversation: conv,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            type: conv.type,
                            nodeNum: conv.nodeNum,
                            title: conv.name,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  void _showNewMessageSheet(BuildContext context, WidgetRef ref) {
    final nodes = ref.read(nodesProvider);
    final myNodeNum = ref.read(myNodeNumProvider);

    // Filter out self from potential recipients
    final otherNodes = nodes.values
        .where((n) => n.nodeNum != myNodeNum)
        .toList();

    AppBottomSheet.show(
      context: context,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              'New Message',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                
              ),
            ),
          ),
          Container(
            height: 1,
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
          ),

          // Nodes section
          if (otherNodes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No other nodes in range',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                    
                  ),
                ),
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'NEARBY NODES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                  
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (final node in otherNodes.take(10))
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
                        
                      ),
                    ),
                  ),
                ),
                title: Text(
                  node.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    
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
        ],
      ),
    );
  }
}

class _Conversation {
  final ConversationType type;
  final int? nodeNum;
  final String name;
  final String? shortName;
  final int? avatarColor;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  _Conversation({
    required this.type,
    this.nodeNum,
    required this.name,
    this.shortName,
    this.avatarColor,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });
}

class _ConversationTile extends StatelessWidget {
  final _Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');

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
                    color: conversation.avatarColor != null
                        ? Color(conversation.avatarColor!)
                        : AppTheme.graphPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      conversation.shortName ??
                          conversation.name.substring(0, 2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        
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
                                  'Start a conversation',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.unreadCount > 0) ...[
                            const SizedBox(width: 8),
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
                                  
                                ),
                              ),
                            ),
                          ],
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
  final FocusNode _messageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageFocusNode.requestFocus();
    });
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _showQuickResponses() async {
    HapticFeedback.selectionClick();
    final settingsService = await ref.read(settingsServiceProvider.future);
    final responses = settingsService.cannedResponses;
    if (!mounted) return;

    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: _QuickResponsesSheet(
        responses: responses,
        onSelect: (text) {
          Navigator.pop(context);
          _messageController.text = text;
          _sendMessage();
        },
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final myNodeNum = ref.read(myNodeNumProvider);
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final to = widget.type == ConversationType.channel
        ? 0xFFFFFFFF
        : widget.nodeNum!;
    final channel = widget.type == ConversationType.channel
        ? widget.channelIndex ?? 0
        : 0;
    final wantAck = widget.type != ConversationType.channel;

    // Create pending message
    final pendingMessage = Message(
      id: messageId,
      from: myNodeNum ?? 0,
      to: to,
      text: text,
      channel: channel,
      sent: true,
      status: MessageStatus.pending,
    );

    // Add to messages immediately for optimistic UI
    ref.read(messagesProvider.notifier).addMessage(pendingMessage);
    _messageController.clear();

    // Haptic feedback for message send
    HapticFeedback.lightImpact();

    // Check if device is connected
    final connectionState = ref.read(connectionStateProvider);
    final isConnected =
        connectionState.valueOrNull == DeviceConnectionState.connected;

    if (!isConnected) {
      // Queue message for later sending
      final offlineQueue = ref.read(offlineQueueProvider);
      offlineQueue.enqueue(
        QueuedMessage(
          id: messageId,
          text: text,
          to: to,
          channel: channel,
          wantAck: wantAck,
        ),
      );

      // Show snackbar that message is queued
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message queued - will send when connected'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      final protocol = ref.read(protocolServiceProvider);
      int packetId;

      if (widget.type == ConversationType.channel) {
        packetId = await protocol.sendMessage(
          text: text,
          to: 0xFFFFFFFF, // Broadcast to channel
          channel: widget.channelIndex ?? 0,
          wantAck: false,
          messageId: messageId,
        );
      } else {
        packetId = await protocol.sendMessage(
          text: text,
          to: widget.nodeNum!,
          channel: 0,
          wantAck: true,
          messageId: messageId,
        );
      }

      // Track the packet ID for delivery updates
      ref.read(messagesProvider.notifier).trackPacket(packetId, messageId);

      // Update status to sent with packet ID
      ref
          .read(messagesProvider.notifier)
          .updateMessage(
            messageId,
            pendingMessage.copyWith(
              status: MessageStatus.sent,
              packetId: packetId,
            ),
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
    // Update to pending, clear error
    ref
        .read(messagesProvider.notifier)
        .updateMessage(
          message.id,
          message.copyWith(
            status: MessageStatus.pending,
            errorMessage: null,
            routingError: null,
          ),
        );

    // Check if device is connected
    final connectionState = ref.read(connectionStateProvider);
    final isConnected =
        connectionState.valueOrNull == DeviceConnectionState.connected;

    if (!isConnected) {
      // Queue message for later sending
      final offlineQueue = ref.read(offlineQueueProvider);
      offlineQueue.enqueue(
        QueuedMessage(
          id: message.id,
          text: message.text,
          to: message.to,
          channel: message.channel ?? 0,
          wantAck: !message.isBroadcast,
        ),
      );

      // Show snackbar that message is queued
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message queued - will send when connected'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      final protocol = ref.read(protocolServiceProvider);
      int packetId;

      if (message.isBroadcast) {
        packetId = await protocol.sendMessage(
          text: message.text,
          to: 0xFFFFFFFF,
          channel: message.channel ?? 0,
          wantAck: false,
          messageId: message.id,
        );
      } else {
        packetId = await protocol.sendMessage(
          text: message.text,
          to: message.to,
          channel: 0,
          wantAck: true,
          messageId: message.id,
        );
      }

      // Track the new packet ID for delivery updates
      ref.read(messagesProvider.notifier).trackPacket(packetId, message.id);

      ref
          .read(messagesProvider.notifier)
          .updateMessage(
            message.id,
            message.copyWith(
              status: MessageStatus.sent,
              errorMessage: null,
              routingError: null,
              packetId: packetId,
            ),
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

  void _showChannelSettings(BuildContext context) {
    final channels = ref.read(channelsProvider);
    final channel = channels.firstWhere(
      (c) => c.index == widget.channelIndex,
      orElse: () =>
          ChannelConfig(index: widget.channelIndex ?? 0, name: '', psk: []),
    );

    AppBottomSheet.show(
      context: context,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: BottomSheetHeader(
              icon: Icons.wifi_tethering,
              title: widget.title,
              subtitle: channel.psk.isNotEmpty ? 'Encrypted' : 'No encryption',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.white),
            title: const Text(
              'Edit Channel',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChannelFormScreen(
                    existingChannel: channel,
                    channelIndex: channel.index,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.key,
              color: channel.psk.isNotEmpty
                  ? Colors.white
                  : AppTheme.textTertiary,
            ),
            title: Text(
              'View Encryption Key',
              style: TextStyle(
                color: channel.psk.isNotEmpty
                    ? Colors.white
                    : AppTheme.textTertiary,
              ),
            ),
            enabled: channel.psk.isNotEmpty,
            onTap: channel.psk.isNotEmpty
                ? () {
                    Navigator.pop(context);
                    _showEncryptionKey(context, channel);
                  }
                : null,
          ),
          ListTile(
            leading: Icon(
              Icons.qr_code,
              color: channel.psk.isNotEmpty
                  ? Colors.white
                  : AppTheme.textTertiary,
            ),
            title: Text(
              'Show QR Code',
              style: TextStyle(
                color: channel.psk.isNotEmpty
                    ? Colors.white
                    : AppTheme.textTertiary,
              ),
            ),
            enabled: channel.psk.isNotEmpty,
            onTap: channel.psk.isNotEmpty
                ? () {
                    Navigator.pop(context);
                    _showQrCode(context, channel);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _showEncryptionKey(BuildContext context, ChannelConfig channel) {
    AppBottomSheet.show(
      context: context,
      child: _EncryptionKeyContent(channel: channel),
    );
  }

  void _showQrCode(BuildContext context, ChannelConfig channel) {
    // Create proper protobuf Channel object for QR code
    final pbChannel = pb.Channel()
      ..index = channel.index
      ..settings = (pb.ChannelSettings()
        ..name = channel.name
        ..psk = channel.psk)
      ..role = channel.index == 0
          ? pb.Channel_Role.PRIMARY
          : pb.Channel_Role.SECONDARY;

    final base64Data = base64Encode(pbChannel.writeToBuffer());
    final channelUrl =
        'https://meshtastic.org/e/#${Uri.encodeComponent(base64Data)}';

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            icon: Icons.qr_code,
            title: widget.title,
            subtitle: 'Scan to join this channel',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: channelUrl,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1F2633),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1F2633),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: channelUrl));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Channel URL copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Copy Channel URL'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final channels = ref.watch(channelsProvider);

    // Determine if messages are encrypted
    // DMs are always encrypted, channels are encrypted if they have a PSK
    bool isEncrypted = true;
    if (widget.type == ConversationType.channel &&
        widget.channelIndex != null) {
      final channelIndex = widget.channelIndex!;
      if (channelIndex < channels.length) {
        final channel = channels[channelIndex];
        isEncrypted = channel.psk.isNotEmpty;
      }
    }

    // Get queued message IDs
    final offlineQueue = ref.watch(offlineQueueProvider);
    final queuedMessageIds = offlineQueue.queue.map((m) => m.id).toSet();

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

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBackground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _dismissKeyboard();
              Navigator.pop(context);
            },
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
                        
                      ),
                    ),
                    Text(
                      widget.type == ConversationType.channel
                          ? 'Channel'
                          : 'Direct Message',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                        
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: widget.type == ConversationType.channel
              ? [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Channel Settings',
                    onPressed: () => _showChannelSettings(context),
                  ),
                ]
              : null,
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
                            filteredMessages[filteredMessages.length -
                                1 -
                                index];
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
                          isEncrypted: isEncrypted,
                          isQueued: queuedMessageIds.contains(message.id),
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
                    // Quick responses button
                    GestureDetector(
                      onTap: () => _showQuickResponses(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          style: const TextStyle(
                            color: Colors.white,
                            
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                            hintStyle: TextStyle(
                              color: AppTheme.textTertiary,
                              
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
                    // Voice messaging not practical over LoRa due to bandwidth limits
                    // Show send button always
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
  final bool isEncrypted;
  final bool isQueued;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.isFromMe,
    required this.senderName,
    required this.senderShortName,
    this.avatarColor,
    this.showSender = true,
    this.isEncrypted = true,
    this.isQueued = false,
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

  /// Get a display-safe short name (replaces unrenderable chars with node ID hex)
  String _getSafeShortName() {
    // Filter to only printable ASCII characters (space through tilde)
    final sanitized = senderShortName.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    if (sanitized.isEmpty) {
      // Fallback to last 4 hex digits of node number
      return message.from
          .toRadixString(16)
          .padLeft(4, '0')
          .substring(
            message.from.toRadixString(16).length > 4
                ? message.from.toRadixString(16).length - 4
                : 0,
          );
    }
    return sanitized.length > 4 ? sanitized.substring(0, 4) : sanitized;
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final isFailed = message.isFailed;
    final isPending = message.isPending;
    final isDelivered = message.status == MessageStatus.delivered;

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
                            
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Encryption indicator
                            if (isEncrypted) ...[
                              Icon(
                                Icons.lock,
                                size: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 3),
                            ],
                            // Queued indicator
                            if (isQueued) ...[
                              Icon(
                                Icons.schedule,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                            ] else if (isPending) ...[
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
                                
                              ),
                            ),
                            if (!isPending && !isFailed && !isQueued) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isDelivered ? Icons.done_all : Icons.done,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ],
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
                    Flexible(
                      child: Text(
                        message.errorMessage ?? 'Failed to send',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.errorRed,
                          
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                  _getSafeShortName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    
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
                        
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEncrypted) ...[
                        const Icon(
                          Icons.lock,
                          size: 10,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        timeFormat.format(message.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                          
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
    );
  }
}

/// Quick responses bottom sheet
class _QuickResponsesSheet extends StatelessWidget {
  final List<CannedResponse> responses;
  final void Function(String text) onSelect;

  const _QuickResponsesSheet({required this.responses, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: AppTheme.primaryGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Quick Responses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.darkBorder, height: 1),
          // Responses grid
          Flexible(
            child: responses.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No quick responses configured.\nAdd some in Settings → Quick responses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.5,
                        ),
                    itemCount: responses.length,
                    itemBuilder: (context, index) {
                      final response = responses[index];
                      return _QuickResponseTile(
                        response: response,
                        onTap: () => onSelect(response.text),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _QuickResponseTile extends StatelessWidget {
  final CannedResponse response;
  final VoidCallback onTap;

  const _QuickResponseTile({required this.response, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.darkBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Center(
            child: Text(
              response.text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _EncryptionKeyContent extends StatefulWidget {
  final ChannelConfig channel;

  const _EncryptionKeyContent({required this.channel});

  @override
  State<_EncryptionKeyContent> createState() => _EncryptionKeyContentState();
}

class _EncryptionKeyContentState extends State<_EncryptionKeyContent> {
  bool _showKey = false;

  @override
  Widget build(BuildContext context) {
    final base64Key = base64Encode(widget.channel.psk);
    final keyBits = widget.channel.psk.length * 8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          icon: Icons.key,
          title: 'Encryption Key',
          subtitle: '$keyBits-bit · ${widget.channel.psk.length} bytes',
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: _showKey
              ? SelectableText(
                  base64Key,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryGreen,
                    fontFamily: 'monospace',
                  ),
                )
              : Text(
                  '•' * 32,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary.withValues(alpha: 0.5),
                    fontFamily: 'monospace',
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showKey = !_showKey),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.darkBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  _showKey ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                label: Text(_showKey ? 'Hide' : 'Show'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showKey
                    ? () {
                        Clipboard.setData(ClipboardData(text: base64Key));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Key copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.darkBackground,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.copy, size: 20),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
