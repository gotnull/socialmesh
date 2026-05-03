// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../../core/l10n/l10n_extension.dart';
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
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/meshcore_contact.dart';
import '../../../models/meshcore_channel.dart';
import '../contact_l10n.dart';
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
  void _dismissKeyboard() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
  }

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
          showErrorSnackBar(context, context.l10n.meshcoreNotConnectedToDevice);
        }
        return;
      }

      // Build and send the message frame
      final session = adapter.session;
      if (session == null || !session.isActive) {
        _markMessageFailed(message.id);
        if (mounted) {
          showErrorSnackBar(context, context.l10n.meshcoreSessionNotActive);
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
        showErrorSnackBar(context, context.l10n.meshcoreFailedToSendMessage);
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

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold.body(
        hasScrollBody: true,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppTheme.errorRed.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    Icon(
                      Icons.link_off_rounded,
                      size: 16,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.meshcoreDisconnectedMessagesWillQueue,
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
                      padding: const EdgeInsets.all(AppTheme.spacing16),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.meshcoreLoadingMessages,
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      );
    }
    final isContact = widget.chatType == MeshCoreChatType.contact;
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: isContact
            ? const [
                Icons.chat_bubble_outline_rounded,
                Icons.send_rounded,
                Icons.forum_outlined,
                Icons.markunread_outlined,
                Icons.alternate_email_rounded,
                Icons.bolt_outlined,
              ]
            : const [
                Icons.forum_outlined,
                Icons.tag_rounded,
                Icons.broadcast_on_personal_outlined,
                Icons.cell_tower_rounded,
                Icons.podcasts_rounded,
                Icons.public_rounded,
              ],
        taglines: [
          context.l10n.meshcoreChatEmptyTagline1,
          context.l10n.meshcoreChatEmptyTagline2,
          context.l10n.meshcoreChatEmptyTagline3,
        ],
        titlePrefix: context.l10n.meshcoreChatEmptyTitlePrefix,
        titleKeyword: context.l10n.meshcoreChatEmptyTitleKeyword,
        titleSuffix: context.l10n.meshcoreChatEmptyTitleSuffix,
        accentColor: _accentColor,
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
          if (!isOutgoing) const SizedBox(width: AppTheme.spacing40),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isOutgoing
                    ? _accentColor.withValues(alpha: 0.3)
                    : context.card,
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
                    style: TextStyle(color: context.textPrimary, fontSize: 15),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      if (isOutgoing) ...[
                        const SizedBox(width: AppTheme.spacing4),
                        _buildStatusIcon(message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isOutgoing) const SizedBox(width: AppTheme.spacing40),
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
            color: context.textTertiary,
          ),
        );
      case MeshCoreMessageDeliveryStatus.sent:
        return Icon(Icons.done_rounded, size: 14, color: context.textTertiary);
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
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              maxLength: 500,
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.l10n.meshcoreTypeMessageHint,
                hintStyle: TextStyle(color: SemanticColors.muted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                counterText: '',
              ),
              style: TextStyle(color: context.textPrimary),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
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
    AppBottomSheet.show<void>(
      context: context,
      child: widget.chatType == MeshCoreChatType.contact
          ? _buildContactInfo()
          : _buildChannelInfo(),
    );
  }

  Widget _buildContactInfo() {
    final contact = widget.contact!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
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
        ),
        SizedBox(height: AppTheme.spacing16),
        Center(
          child: Text(
            contact.name,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacing8),
        Center(
          child: Text(
            contact.localizedTypeLabel(context.l10n),
            style: TextStyle(color: _accentColor, fontSize: 14),
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: context.l10n.meshcoreDeviceInfo),
        InfoTable(
          rows: [
            InfoTableRow(
              label: context.l10n.meshcorePublicKeySettingsLabel,
              value: contact.publicKeyHex,
              icon: Icons.key_outlined,
            ),
            InfoTableRow(
              label: context.l10n.meshcoreChatInfoPath,
              value: contact.localizedPathLabel(context.l10n),
              icon: Icons.alt_route_outlined,
            ),
            InfoTableRow(
              label: context.l10n.meshcoreChatInfoLastSeen,
              value: _formatDateTime(contact.lastSeen),
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacing16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: contact.publicKeyHex));
              showSuccessSnackBar(
                context,
                context.l10n.meshcorePublicKeyCopied,
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(context.l10n.meshcoreCopyPublicKey),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelInfo() {
    final channel = widget.channel!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: _accentColor.withValues(alpha: 0.2),
            child: Icon(
              channel.isPublic ? Icons.tag_rounded : Icons.lock_rounded,
              color: _accentColor,
              size: 32,
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        Center(
          child: Text(
            channel.displayName,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacing8),
        Center(
          child: Text(
            channel.isPublic
                ? context.l10n.meshcorePublicChannel
                : context.l10n.meshcorePrivateChannel,
            style: TextStyle(color: _accentColor, fontSize: 14),
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: context.l10n.meshcoreDeviceInfo),
        InfoTable(
          rows: [
            InfoTableRow(
              label: context.l10n.meshcoreChannelInfoIndex,
              value: '${channel.index}',
              icon: Icons.tag,
            ),
            InfoTableRow(
              label: context.l10n.meshcoreChannelInfoPsk,
              value: channel.pskHex,
              icon: Icons.vpn_key_outlined,
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacing16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: channel.pskHex));
              showSuccessSnackBar(
                context,
                context.l10n.meshcoreChannelPskCopied,
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(context.l10n.meshcoreCopyChannelCode),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return context.l10n.meshcoreTimeAgoDays(diff.inDays);
    } else if (diff.inHours > 0) {
      return context.l10n.meshcoreTimeAgoHours(diff.inHours);
    } else if (diff.inMinutes > 0) {
      return context.l10n.meshcoreTimeAgoMinutes(diff.inMinutes);
    } else {
      return context.l10n.meshcoreJustNow;
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
