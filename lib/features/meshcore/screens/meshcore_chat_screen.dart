// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/meshcore_constants.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../models/meshcore_contact.dart';
import '../../../models/meshcore_channel.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../providers/meshcore_message_providers.dart';
import '../../../services/meshcore/protocol/meshcore_frame.dart';
import '../../../services/meshcore/storage/meshcore_message_store.dart';
import '../../../services/meshcore/storage/meshcore_contact_store.dart';
import '../../../utils/snackbar.dart';

/// Types of MeshCore chat conversations.
enum MeshCoreChatType { contact, channel }

/// MeshCore Chat Screen - for messaging contacts or channels.
class MeshCoreChatScreen extends ConsumerStatefulWidget {
  final MeshCoreChatType chatType;
  final MeshCoreContact? contact;
  final MeshCoreChannel? channel;

  const MeshCoreChatScreen.contact({
    super.key,
    required MeshCoreContact this.contact,
  }) : chatType = MeshCoreChatType.contact,
       channel = null;

  const MeshCoreChatScreen.channel({
    super.key,
    required MeshCoreChannel this.channel,
  }) : chatType = MeshCoreChatType.channel,
       contact = null;

  @override
  ConsumerState<MeshCoreChatScreen> createState() => _MeshCoreChatScreenState();
}

class _MeshCoreChatScreenState extends ConsumerState<MeshCoreChatScreen>
    with LifecycleSafeMixin<MeshCoreChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<MeshCoreMessage> _messages = [];
  bool _isSending = false;
  bool _isLoading = true;
  StreamSubscription<MeshCoreFrame>? _frameSubscription;
  final MeshCoreMessageStore _messageStore = MeshCoreMessageStore();
  final MeshCoreContactStore _contactStore = MeshCoreContactStore();

  String get _conversationId {
    if (widget.chatType == MeshCoreChatType.contact) {
      return widget.contact!.publicKeyHex;
    } else {
      return 'channel_${widget.channel!.index}';
    }
  }

  String get _title {
    if (widget.chatType == MeshCoreChatType.contact) {
      return widget.contact!.name;
    } else {
      return widget.channel!.displayName;
    }
  }

  Color get _accentColor {
    if (widget.chatType == MeshCoreChatType.contact) {
      return AccentColors.cyan;
    } else {
      return AccentColors.purple;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToIncomingMessages();
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    // Load persisted messages from storage
    setState(() => _isLoading = true);
    try {
      await _messageStore.init();
      await _contactStore.init();

      final storedMessages = widget.chatType == MeshCoreChatType.contact
          ? await _messageStore.loadContactMessages(_conversationId)
          : await _messageStore.loadChannelMessages(widget.channel!.index);

      final messages = storedMessages.map((stored) {
        return MeshCoreMessage(
          id: stored.id,
          text: stored.text,
          timestamp: stored.timestamp,
          isOutgoing: stored.isOutgoing,
          status: _convertStatus(stored.status),
          senderKey: stored.senderKey,
          pathLength: stored.pathLength,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(messages);
          _isLoading = false;
        });
        // Clear unread count when opening chat
        if (widget.chatType == MeshCoreChatType.contact) {
          await _contactStore.clearUnreadCount(_conversationId);
          ref
              .read(meshCoreConversationsProvider.notifier)
              .markAsRead(_conversationId);
        }
        // Scroll to bottom after loading
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      AppLogging.storage('MeshCore Chat: Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToIncomingMessages() {
    // Subscribe to incoming messages from the session
    final session = ref.read(meshCoreSessionProvider);
    if (session != null && session.isActive) {
      _frameSubscription = session.frameStream.listen(_handleIncomingFrame);
    }
  }

  void _handleIncomingFrame(MeshCoreFrame frame) {
    // Handle incoming messages for this conversation
    if (widget.chatType == MeshCoreChatType.contact) {
      if (frame.command == MeshCoreResponses.contactMsgRecv ||
          frame.command == MeshCoreResponses.contactMsgRecvV3) {
        _handleIncomingContactMessage(frame);
      }
    } else {
      if (frame.command == MeshCoreResponses.channelMsgRecv ||
          frame.command == MeshCoreResponses.channelMsgRecvV3) {
        _handleIncomingChannelMessage(frame);
      }
    }

    // Handle delivery confirmation
    if (frame.command == MeshCorePushCodes.sendConfirmed) {
      _handleDeliveryConfirmation(frame);
    }
  }

  void _handleIncomingContactMessage(MeshCoreFrame frame) {
    if (frame.payload.length < 37) return;

    // Parse sender key and check if it's from our contact
    final senderKey = Uint8List.fromList(frame.payload.sublist(0, 32));
    final senderKeyHex = _bytesToHex(senderKey);

    // Only process messages from the contact we're chatting with
    if (senderKeyHex != widget.contact!.publicKeyHex) return;

    final timestampRaw = _readUint32LE(frame.payload, 32);
    final text = _readCString(frame.payload, 37);

    final message = MeshCoreMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_$senderKeyHex',
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampRaw * 1000),
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: senderKey,
    );

    if (mounted) {
      setState(() => _messages.add(message));
      _persistMessage(message);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _handleIncomingChannelMessage(MeshCoreFrame frame) {
    if (frame.payload.length < 38) return;

    // Parse channel index and check if it matches
    final channelIndex = frame.payload[0];
    if (channelIndex != widget.channel!.index) return;

    final senderKey = Uint8List.fromList(frame.payload.sublist(1, 33));
    final timestampRaw = _readUint32LE(frame.payload, 33);
    final text = _readCString(frame.payload, 38);

    final message = MeshCoreMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_ch$channelIndex',
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampRaw * 1000),
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: senderKey,
    );

    if (mounted) {
      setState(() => _messages.add(message));
      _persistMessage(message);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _handleDeliveryConfirmation(MeshCoreFrame frame) {
    // Mark the most recent pending outgoing message as delivered
    if (mounted && _messages.isNotEmpty) {
      final lastPending = _messages.lastIndexWhere(
        (m) =>
            m.isOutgoing && m.status == MeshCoreMessageDeliveryStatus.pending,
      );
      if (lastPending >= 0) {
        setState(() {
          _messages[lastPending] = _messages[lastPending].copyWith(
            status: MeshCoreMessageDeliveryStatus.delivered,
          );
        });
        _persistMessage(_messages[lastPending]);
      }
    }
  }

  Future<void> _persistMessage(MeshCoreMessage message) async {
    try {
      // Get sender key - for outgoing messages use self, for incoming use the provided key
      final selfInfo = ref.read(meshCoreSelfInfoProvider).selfInfo;
      final senderKey = message.isOutgoing
          ? (selfInfo?.pubKey ?? Uint8List(32))
          : (message.senderKey ?? Uint8List(32));

      final stored = MeshCoreStoredMessage(
        id: message.id,
        senderKey: senderKey,
        text: message.text,
        timestamp: message.timestamp,
        isOutgoing: message.isOutgoing,
        status: _convertToStoredStatus(message.status),
        pathLength: message.pathLength,
        isChannelMessage: widget.chatType == MeshCoreChatType.channel,
        channelIndex: widget.channel?.index,
      );

      if (widget.chatType == MeshCoreChatType.contact) {
        await _messageStore.addContactMessage(_conversationId, stored);
      } else {
        await _messageStore.addChannelMessage(widget.channel!.index, stored);
      }
    } catch (e) {
      AppLogging.storage('MeshCore Chat: Error persisting message: $e');
    }
  }

  MeshCoreMessageDeliveryStatus _convertStatus(MeshCoreMessageStatus status) {
    switch (status) {
      case MeshCoreMessageStatus.pending:
        return MeshCoreMessageDeliveryStatus.pending;
      case MeshCoreMessageStatus.sent:
        return MeshCoreMessageDeliveryStatus.sent;
      case MeshCoreMessageStatus.delivered:
        return MeshCoreMessageDeliveryStatus.delivered;
      case MeshCoreMessageStatus.failed:
        return MeshCoreMessageDeliveryStatus.failed;
    }
  }

  MeshCoreMessageStatus _convertToStoredStatus(
    MeshCoreMessageDeliveryStatus status,
  ) {
    switch (status) {
      case MeshCoreMessageDeliveryStatus.pending:
        return MeshCoreMessageStatus.pending;
      case MeshCoreMessageDeliveryStatus.sent:
        return MeshCoreMessageStatus.sent;
      case MeshCoreMessageDeliveryStatus.delivered:
        return MeshCoreMessageStatus.delivered;
      case MeshCoreMessageDeliveryStatus.failed:
        return MeshCoreMessageStatus.failed;
    }
  }

  // Helper functions
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static int _readUint32LE(Uint8List data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  static String _readCString(Uint8List data, int offset) {
    final chars = <int>[];
    for (int i = offset; i < data.length && data[i] != 0; i++) {
      chars.add(data[i]);
    }
    return String.fromCharCodes(chars);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Capture providers before any await
    final coordinator = ref.read(connectionCoordinatorProvider);

    setState(() {
      _isSending = true;
    });

    try {
      // Create local message with pending status
      final message = MeshCoreMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        timestamp: DateTime.now(),
        isOutgoing: true,
        status: MeshCoreMessageDeliveryStatus.pending,
      );

      setState(() {
        _messages.add(message);
        _messageController.clear();
      });

      // Persist immediately as pending
      await _persistMessage(message);

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });

      // Send via MeshCore protocol (coordinator captured before await)
      final adapter = coordinator.meshCoreAdapter;

      if (adapter == null) {
        _markMessageFailed(message.id);
        if (mounted) {
          showErrorSnackBar(context, 'Not connected to MeshCore device');
        }
        return;
      }

      // Build and send the message frame
      final session = adapter.session;
      if (session == null || !session.isActive) {
        _markMessageFailed(message.id);
        if (mounted) {
          showErrorSnackBar(context, 'MeshCore session not active');
        }
        return;
      }

      // Send to contact or channel
      if (widget.chatType == MeshCoreChatType.contact) {
        final frame = _buildSendTextMsgFrame(widget.contact!.publicKey, text);
        await session.sendFrame(frame);
      } else {
        final frame = _buildSendChannelTextMsgFrame(
          widget.channel!.index,
          text,
        );
        await session.sendFrame(frame);
      }

      // Mark as sent (delivery confirmation will update to delivered)
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index >= 0) {
            _messages[index] = _messages[index].copyWith(
              status: MeshCoreMessageDeliveryStatus.sent,
            );
          }
        });
        _persistMessage(_messages.firstWhere((m) => m.id == message.id));
      }

      AppLogging.protocol('MeshCore Chat: Sent message to $_title: $text');
    } catch (e) {
      AppLogging.protocol('MeshCore Chat: Error sending message: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send message');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _markMessageFailed(String messageId) {
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          _messages[index] = _messages[index].copyWith(
            status: MeshCoreMessageDeliveryStatus.failed,
          );
          _persistMessage(_messages[index]);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;

    return GlassScaffold.body(
      title: _title,
      actions: [
        IconButton(
          icon: Icon(Icons.info_outline_rounded, color: _accentColor),
          onPressed: _showChatInfo,
        ),
      ],
      body: Column(
        children: [
          // Connection status banner
          if (!isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.errorRed.withValues(alpha: 0.2),
              child: Row(
                children: [
                  Icon(
                    Icons.link_off_rounded,
                    size: 16,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Disconnected - Messages will queue',
                    style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.chatType == MeshCoreChatType.contact
                ? Icons.chat_bubble_outline_rounded
                : Icons.forum_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MeshCoreMessage message) {
    final isOutgoing = message.isOutgoing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isOutgoing
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isOutgoing) const SizedBox(width: 40),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isOutgoing
                    ? _accentColor.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
                  bottomRight: Radius.circular(isOutgoing ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                      if (isOutgoing) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isOutgoing) const SizedBox(width: 40),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusIcon(MeshCoreMessageDeliveryStatus status) {
    switch (status) {
      case MeshCoreMessageDeliveryStatus.pending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        );
      case MeshCoreMessageDeliveryStatus.sent:
        return Icon(
          Icons.done_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: 0.5),
        );
      case MeshCoreMessageDeliveryStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 14, color: _accentColor);
      case MeshCoreMessageDeliveryStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: AppTheme.errorRed,
        );
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accentColor,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: _accentColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        if (widget.chatType == MeshCoreChatType.contact) {
          return _buildContactInfo();
        } else {
          return _buildChannelInfo();
        }
      },
    );
  }

  Widget _buildContactInfo() {
    final contact = widget.contact!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _accentColor.withValues(alpha: 0.2),
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: _accentColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            contact.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            contact.typeLabel,
            style: TextStyle(color: _accentColor, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Public Key', contact.shortPubKeyHex),
          _buildInfoRow('Path', contact.pathLabel),
          _buildInfoRow('Last Seen', _formatDateTime(contact.lastSeen)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: contact.publicKeyHex));
                showSuccessSnackBar(context, 'Public key copied');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Public Key'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelInfo() {
    final channel = widget.channel!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _accentColor.withValues(alpha: 0.2),
            child: Icon(
              channel.isPublic ? Icons.tag_rounded : Icons.lock_rounded,
              color: _accentColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            channel.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            channel.isPublic ? 'Public Channel' : 'Private Channel',
            style: TextStyle(color: _accentColor, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Index', '${channel.index}'),
          _buildInfoRow(
            'PSK',
            channel.pskHex.length >= 16
                ? '${channel.pskHex.substring(0, 8)}...${channel.pskHex.substring(channel.pskHex.length - 8)}'
                : channel.pskHex,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: channel.pskHex));
                showSuccessSnackBar(context, 'Channel PSK copied');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Channel Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Build CMD_SEND_TXT_MSG frame for contact message.
  /// Format: [cmd][txt_type][attempt][timestamp x4][pub_key_prefix x6][text...]\0
  MeshCoreFrame _buildSendTextMsgFrame(Uint8List recipientPubKey, String text) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final builder = BytesBuilder();
    builder.addByte(0); // txt_type = plain
    builder.addByte(0); // attempt = 0
    // timestamp (4 bytes little-endian)
    builder.addByte(timestamp & 0xFF);
    builder.addByte((timestamp >> 8) & 0xFF);
    builder.addByte((timestamp >> 16) & 0xFF);
    builder.addByte((timestamp >> 24) & 0xFF);
    // pub_key prefix (first 6 bytes)
    builder.add(recipientPubKey.sublist(0, 6));
    // text + null terminator
    builder.add(utf8.encode(text));
    builder.addByte(0);

    return MeshCoreFrame(
      command: MeshCoreCommands.sendTxtMsg,
      payload: builder.toBytes(),
    );
  }

  /// Build CMD_SEND_CHANNEL_TXT_MSG frame for channel message.
  /// Format: [cmd][txt_type][channel_idx][timestamp x4][text...]\0
  MeshCoreFrame _buildSendChannelTextMsgFrame(int channelIndex, String text) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final builder = BytesBuilder();
    builder.addByte(0); // txt_type = plain
    builder.addByte(channelIndex);
    // timestamp (4 bytes little-endian)
    builder.addByte(timestamp & 0xFF);
    builder.addByte((timestamp >> 8) & 0xFF);
    builder.addByte((timestamp >> 16) & 0xFF);
    builder.addByte((timestamp >> 24) & 0xFF);
    // text + null terminator
    builder.add(utf8.encode(text));
    builder.addByte(0);

    return MeshCoreFrame(
      command: MeshCoreCommands.sendChannelTxtMsg,
      payload: builder.toBytes(),
    );
  }
}
