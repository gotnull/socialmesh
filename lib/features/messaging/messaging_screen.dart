import '../../core/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../models/mesh_models.dart';
import '../../models/canned_response.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/node_avatar.dart';
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/channel.pbenum.dart' as channel_pbenum;
import '../../services/messaging/offline_queue_service.dart';
import '../../services/haptic_service.dart';
import '../channels/channel_form_screen.dart';
import '../settings/canned_responses_screen.dart';
import '../settings/device_management_screen.dart';
import '../nodes/nodes_screen.dart';
import '../navigation/main_shell.dart';
import 'widgets/message_context_menu.dart';
import '../../core/widgets/loading_indicator.dart';

/// Conversation type enum
enum ConversationType { channel, directMessage }

/// Contact filter enum
enum ContactFilter { all, favorites, messaged, unread, online }

/// Main messaging screen - shows list of conversations
class MessagingScreen extends ConsumerStatefulWidget {
  /// When true, shows only the body content without AppBar/Scaffold
  /// Used when embedded in tabs
  final bool embedded;

  const MessagingScreen({super.key, this.embedded = false});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  ContactFilter _currentFilter = ContactFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final messages = ref.watch(messagesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Build map of DM info per node (for showing last message, unread count)
    final dmInfoByNode = <int, _DmInfo>{};
    for (final message in messages) {
      if (message.isDirect) {
        final otherNode = message.from == myNodeNum ? message.to : message.from;
        final existing = dmInfoByNode[otherNode];
        final isUnread = message.received && message.from == otherNode;

        if (existing == null) {
          dmInfoByNode[otherNode] = _DmInfo(
            lastMessage: message.text,
            lastMessageTime: message.timestamp,
            unreadCount: isUnread ? 1 : 0,
            senderDisplayName: message.senderDisplayName,
            senderShortName: message.senderShortName,
            senderAvatarColor: message.senderAvatarColor,
          );
        } else {
          // Update if this message is newer
          if (message.timestamp.isAfter(existing.lastMessageTime)) {
            dmInfoByNode[otherNode] = _DmInfo(
              lastMessage: message.text,
              lastMessageTime: message.timestamp,
              unreadCount: existing.unreadCount + (isUnread ? 1 : 0),
              senderDisplayName: message.senderDisplayName,
              senderShortName: message.senderShortName,
              senderAvatarColor: message.senderAvatarColor,
            );
          } else if (isUnread) {
            dmInfoByNode[otherNode] = _DmInfo(
              lastMessage: existing.lastMessage,
              lastMessageTime: existing.lastMessageTime,
              unreadCount: existing.unreadCount + 1,
              senderDisplayName: existing.senderDisplayName,
              senderShortName: existing.senderShortName,
              senderAvatarColor: existing.senderAvatarColor,
            );
          }
        }
      }
    }

    // Build contacts list from ALL nodes (except self)
    final List<_Contact> contacts = [];

    for (final node in nodes.values) {
      if (node.nodeNum == myNodeNum) continue;

      final dmInfo = dmInfoByNode[node.nodeNum];
      contacts.add(
        _Contact(
          nodeNum: node.nodeNum,
          displayName: node.displayName,
          shortName: node.shortName,
          avatarColor: node.avatarColor,
          isOnline: node.isOnline,
          isFavorite: node.isFavorite,
          lastMessage: dmInfo?.lastMessage,
          lastMessageTime: dmInfo?.lastMessageTime,
          unreadCount: dmInfo?.unreadCount ?? 0,
        ),
      );
    }

    // Also add nodes we have messages from but aren't in the nodes list anymore
    for (final entry in dmInfoByNode.entries) {
      final nodeNum = entry.key;
      if (nodes.containsKey(nodeNum)) continue; // Already added

      final dmInfo = entry.value;
      contacts.add(
        _Contact(
          nodeNum: nodeNum,
          displayName:
              dmInfo.senderDisplayName ??
              'Node ${nodeNum.toRadixString(16).toUpperCase()}',
          shortName: dmInfo.senderShortName,
          avatarColor: dmInfo.senderAvatarColor,
          isOnline: false,
          lastMessage: dmInfo.lastMessage,
          lastMessageTime: dmInfo.lastMessageTime,
          unreadCount: dmInfo.unreadCount,
        ),
      );
    }

    // Sort: online first, then by name
    contacts.sort((a, b) {
      // Unread messages first
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (b.unreadCount > 0 && a.unreadCount == 0) return 1;
      // Then online nodes
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      // Then alphabetically
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    // Calculate filter counts
    final favoritesCount = contacts.where((c) => c.isFavorite).length;
    final messagedCount = contacts.where((c) => c.hasMessages).length;
    final unreadCount = contacts.where((c) => c.unreadCount > 0).length;
    final onlineCount = contacts.where((c) => c.isOnline).length;

    // Apply filter
    var filteredContacts = contacts;
    switch (_currentFilter) {
      case ContactFilter.all:
        break;
      case ContactFilter.favorites:
        filteredContacts = contacts.where((c) => c.isFavorite).toList();
        break;
      case ContactFilter.messaged:
        filteredContacts = contacts.where((c) => c.hasMessages).toList();
        break;
      case ContactFilter.unread:
        filteredContacts = contacts.where((c) => c.unreadCount > 0).toList();
        break;
      case ContactFilter.online:
        filteredContacts = contacts.where((c) => c.isOnline).toList();
        break;
    }

    // Then filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredContacts = filteredContacts.where((c) {
        return c.displayName.toLowerCase().contains(query) ||
            (c.shortName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Build the body content
    final bodyContent = Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search contacts',
                hintStyle: TextStyle(color: context.textTertiary),
                prefixIcon: Icon(Icons.search, color: context.textTertiary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: context.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        // Filter chips
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: EdgeFade.end(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _ContactFilterChip(
                        label: 'All',
                        count: contacts.length,
                        isSelected: _currentFilter == ContactFilter.all,
                        onTap: () =>
                            setState(() => _currentFilter = ContactFilter.all),
                      ),
                      SizedBox(width: 8),
                      _ContactFilterChip(
                        label: 'Favorites',
                        count: favoritesCount,
                        isSelected: _currentFilter == ContactFilter.favorites,
                        icon: Icons.star,
                        color: AppTheme.warningYellow,
                        onTap: () => setState(
                          () => _currentFilter = ContactFilter.favorites,
                        ),
                      ),
                      SizedBox(width: 8),
                      _ContactFilterChip(
                        label: 'Messaged',
                        count: messagedCount,
                        isSelected: _currentFilter == ContactFilter.messaged,
                        icon: Icons.chat_bubble_outline,
                        color: AppTheme.primaryBlue,
                        onTap: () => setState(
                          () => _currentFilter = ContactFilter.messaged,
                        ),
                      ),
                      SizedBox(width: 8),
                      _ContactFilterChip(
                        label: 'Unread',
                        count: unreadCount,
                        isSelected: _currentFilter == ContactFilter.unread,
                        icon: Icons.mark_email_unread_outlined,
                        color: AccentColors.red,
                        onTap: () => setState(
                          () => _currentFilter = ContactFilter.unread,
                        ),
                      ),
                      SizedBox(width: 8),
                      _ContactFilterChip(
                        label: 'Online',
                        count: onlineCount,
                        isSelected: _currentFilter == ContactFilter.online,
                        color: AccentColors.green,
                        onTap: () => setState(
                          () => _currentFilter = ContactFilter.online,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        // Divider
        Container(height: 1, color: context.border.withValues(alpha: 0.3)),
        // Contacts list
        Expanded(
          child: filteredContacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.people_outline,
                          size: 40,
                          color: context.textTertiary,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No contacts match "$_searchQuery"'
                            : _currentFilter != ContactFilter.all
                            ? 'No ${_currentFilter.name} contacts'
                            : 'No contacts yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          'Discovered nodes will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _searchQuery = ''),
                          child: const Text('Clear search'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = filteredContacts[index];
                    final animationsEnabled = ref.watch(
                      animationsEnabledProvider,
                    );
                    return Perspective3DSlide(
                      index: index,
                      direction: SlideDirection.left,
                      enabled: animationsEnabled,
                      child: _ContactTile(
                        contact: contact,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                type: ConversationType.directMessage,
                                nodeNum: contact.nodeNum,
                                title: contact.displayName,
                                avatarColor: contact.avatarColor,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    // If embedded (in tabs), return just the body with gesture detector
    if (widget.embedded) {
      return GestureDetector(
        onTap: _dismissKeyboard,
        child: Container(color: context.background, child: bodyContent),
      );
    }

    // Full standalone screen with AppBar
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'message_routing',
        stepKeys: const {},
        child: Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            leading: const HamburgerMenuButton(),
            centerTitle: true,
            title: Text(
              'Contacts${contacts.isNotEmpty ? ' (${contacts.length})' : ''}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            actions: [const DeviceStatusButton(), const _MessagingPopupMenu()],
          ),
          body: bodyContent,
        ),
      ),
    );
  }
}

/// Helper class to track DM info for a node
class _DmInfo {
  final String? lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? senderDisplayName;
  final String? senderShortName;
  final int? senderAvatarColor;

  _DmInfo({
    this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.senderDisplayName,
    this.senderShortName,
    this.senderAvatarColor,
  });
}

/// Contact model representing a messageable node
class _Contact {
  final int nodeNum;
  final String displayName;
  final String? shortName;
  final int? avatarColor;
  final bool isOnline;
  final bool isFavorite;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  _Contact({
    required this.nodeNum,
    required this.displayName,
    this.shortName,
    this.avatarColor,
    this.isOnline = false,
    this.isFavorite = false,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  bool get hasMessages => lastMessage != null;
}

class _ContactTile extends StatelessWidget {
  final _Contact contact;
  final VoidCallback onTap;

  const _ContactTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with online indicator
              Stack(
                children: [
                  NodeAvatar(
                    text:
                        contact.shortName ??
                        (contact.displayName.length >= 2
                            ? contact.displayName.substring(0, 2)
                            : contact.displayName),
                    color: contact.avatarColor != null
                        ? Color(contact.avatarColor!)
                        : AppTheme.graphPurple,
                    size: 48,
                  ),
                  if (contact.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.card, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (contact.unreadCount > 0) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${contact.unreadCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      contact.lastMessage ??
                          (contact.isOnline ? 'Online' : 'Offline'),
                      style: TextStyle(
                        fontSize: 14,
                        color: contact.lastMessage != null
                            ? context.textSecondary
                            : (contact.isOnline
                                  ? AppTheme.successGreen
                                  : context.textTertiary),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
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
  final int? avatarColor;

  const ChatScreen({
    super.key,
    required this.type,
    this.channelIndex,
    this.nodeNum,
    required this.title,
    this.avatarColor,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageFocusNode.requestFocus();
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _showNodeDetails() {
    if (widget.type != ConversationType.directMessage ||
        widget.nodeNum == null) {
      return;
    }
    final nodes = ref.read(nodesProvider);
    final node = nodes[widget.nodeNum];
    if (node != null) {
      showNodeDetailsSheet(context, node, false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _messageFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showQuickResponses() async {
    ref.haptics.buttonTap();
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
    final nodes = ref.read(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final to = widget.type == ConversationType.channel
        ? 0xFFFFFFFF
        : widget.nodeNum!;
    final channel = widget.type == ConversationType.channel
        ? widget.channelIndex ?? 0
        : 0;
    final wantAck = widget.type != ConversationType.channel;

    // Create pending message with sender info cached
    final pendingMessage = Message(
      id: messageId,
      from: myNodeNum ?? 0,
      to: to,
      text: text,
      channel: channel,
      sent: true,
      status: MessageStatus.pending,
      source: MessageSource.manual,
      senderLongName: myNode?.longName,
      senderShortName: myNode?.shortName,
      senderAvatarColor: myNode?.avatarColor,
    );

    // Add to messages immediately for optimistic UI
    ref.read(messagesProvider.notifier).addMessage(pendingMessage);
    _messageController.clear();

    // Haptic feedback for message send
    ref.haptics.messageSent();

    // Check if device is connected
    final connectionState = ref.read(connectionStateProvider);
    final isConnected =
        connectionState.value == DeviceConnectionState.connected;

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
        showInfoSnackBar(context, 'Message queued - will send when connected');
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
          source: MessageSource.manual,
        );
        // Channel messages don't get ACKs, so no tracking needed
      } else {
        // Pre-generate packet ID and track BEFORE sending to avoid race condition
        // where ACK arrives before tracking is set up
        packetId = await protocol.sendMessageWithPreTracking(
          text: text,
          to: widget.nodeNum!,
          channel: 0,
          wantAck: true,
          messageId: messageId,
          onPacketIdGenerated: (id) {
            ref.read(messagesProvider.notifier).trackPacket(id, messageId);
          },
          source: MessageSource.manual,
        );
      }

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
        connectionState.value == DeviceConnectionState.connected;

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
        showInfoSnackBar(context, 'Message queued - will send when connected');
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
          source: message.source, // Preserve original source
        );
        // Broadcast messages don't get ACKs, no tracking needed
      } else {
        // Pre-track before sending to avoid race condition
        packetId = await protocol.sendMessageWithPreTracking(
          text: message.text,
          to: message.to,
          channel: 0,
          wantAck: true,
          messageId: message.id,
          onPacketIdGenerated: (id) {
            ref.read(messagesProvider.notifier).trackPacket(id, message.id);
          },
          source: message.source, // Preserve original source
        );
      }

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

  void _showPkiFixSheet(Message message) {
    final nodes = ref.read(nodesProvider);
    final targetNode = nodes[message.to];
    final targetName = targetNode?.displayName ?? 'Unknown Node';

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            icon: Icons.key_off,
            title: 'Encryption Key Issue',
            subtitle: 'Direct message to $targetName failed',
          ),
          SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningYellow.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.warningYellow,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message.routingError?.fixSuggestion ??
                        'The encryption keys may be out of sync. This can happen when a node has been reset or rolled out of the mesh database.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Request User Info button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final protocol = ref.read(protocolServiceProvider);
                try {
                  await protocol.requestNodeInfo(message.to);
                  if (mounted) {
                    showInfoSnackBar(
                      context,
                      'Requested fresh info from $targetName',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    showErrorSnackBar(context, 'Failed to request info: $e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(
                'Request User Info',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Retry message button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _retryMessage(message);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textSecondary,
                side: BorderSide(color: context.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send, size: 20),
              label: const Text(
                'Retry Message',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Advanced options link
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeviceManagementScreen(),
                ),
              );
            },
            child: Text(
              'Advanced: Reset Node Database',
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Delete Message',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this message? This only removes it locally.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(messagesProvider.notifier).deleteMessage(message.id);
              Navigator.pop(context);
              showSuccessSnackBar(this.context, 'Message deleted');
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );
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
            leading: Icon(Icons.edit, color: context.textSecondary),
            title: Text(
              'Edit Channel',
              style: TextStyle(color: context.textPrimary),
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
                  ? context.textPrimary
                  : context.textTertiary,
            ),
            title: Text(
              'View Encryption Key',
              style: TextStyle(
                color: channel.psk.isNotEmpty
                    ? context.textPrimary
                    : context.textTertiary,
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
                  ? context.textPrimary
                  : context.textTertiary,
            ),
            title: Text(
              'Show QR Code',
              style: TextStyle(
                color: channel.psk.isNotEmpty
                    ? context.textPrimary
                    : context.textTertiary,
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
    final pbChannel = channel_pb.Channel()
      ..index = channel.index
      ..settings = (channel_pb.ChannelSettings()
        ..name = channel.name
        ..psk = channel.psk)
      ..role = channel.index == 0
          ? channel_pbenum.Channel_Role.PRIMARY
          : channel_pbenum.Channel_Role.SECONDARY;

    final base64Data = base64Encode(pbChannel.writeToBuffer());
    final channelUrl = 'socialmesh://channel/$base64Data';

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
                showSuccessSnackBar(context, 'Channel URL copied to clipboard');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
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

    // Debug: Log myNodeNum to help diagnose message direction issues
    AppLogging.messages(
      '📨 ConversationScreen: myNodeNum=$myNodeNum, type=${widget.type}, nodeNum=${widget.nodeNum}',
    );

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
      // Debug: Log all messages and their channel/broadcast status
      AppLogging.messages(
        '📨 Channel ${widget.channelIndex}: Total messages=${messages.length}, '
        'filtering for channel=${widget.channelIndex}',
      );
      for (final m in messages.where((m) => m.channel == widget.channelIndex)) {
        AppLogging.messages(
          '📨   Message: from=${m.from}, to=${m.to.toRadixString(16)}, '
          'channel=${m.channel}, isBroadcast=${m.isBroadcast}, sent=${m.sent}',
        );
      }
      filteredMessages = messages
          .where((m) => m.channel == widget.channelIndex && m.isBroadcast)
          .toList();
      AppLogging.messages(
        '📨 After filter: ${filteredMessages.length} messages',
      );
    } else {
      filteredMessages = messages
          .where(
            (m) =>
                m.isDirect &&
                (m.from == widget.nodeNum || m.to == widget.nodeNum),
          )
          .toList();
    }

    // Apply search filter if searching
    if (_isSearching && _searchQuery.isNotEmpty) {
      filteredMessages = filteredMessages
          .where((m) => m.text.toLowerCase().contains(_searchQuery))
          .toList();
    }

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.textPrimary),
            onPressed: () {
              _dismissKeyboard();
              if (_isSearching) {
                _toggleSearch();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: GestureDetector(
            onTap: widget.type == ConversationType.directMessage
                ? _showNodeDetails
                : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                if (widget.type == ConversationType.channel)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tag,
                      color: context.accentColor,
                      size: 18,
                    ),
                  )
                else
                  NodeAvatar(
                    text: widget.title.length >= 2
                        ? widget.title.substring(0, 2)
                        : widget.title,
                    color: widget.avatarColor != null
                        ? Color(widget.avatarColor!)
                        : AppTheme.graphPurple,
                    size: 36,
                  ),
                SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AutoScrollText(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        widget.type == ConversationType.channel
                            ? 'Channel'
                            : 'Direct Message',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: _isSearching ? context.accentColor : context.textPrimary,
              ),
              tooltip: _isSearching ? 'Close Search' : 'Search Messages',
              onPressed: _toggleSearch,
            ),
            if (widget.type == ConversationType.channel)
              IconButton(
                icon: Icon(Icons.settings, color: context.textPrimary),
                tooltip: 'Channel Settings',
                onPressed: () => _showChannelSettings(context),
              ),
          ],
        ),
        body: Column(
          children: [
            // Search bar (same design as Nodes screen)
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Find a message',
                      hintStyle: TextStyle(color: context.textTertiary),
                      prefixIcon: Icon(
                        Icons.search,
                        color: context.textTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            // Divider when searching
            if (_isSearching)
              Container(
                height: 1,
                color: context.border.withValues(alpha: 0.3),
              ),
            // Search results count
            if (_isSearching && _searchQuery.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: context.card,
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: context.textSecondary.withValues(alpha: 0.8),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${filteredMessages.length} message${filteredMessages.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            // Messages
            Expanded(
              child: filteredMessages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSearching
                                ? Icons.search_off
                                : Icons.chat_bubble_outline,
                            size: 48,
                            color: context.textTertiary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _isSearching
                                ? 'No messages match your search'
                                : widget.type == ConversationType.channel
                                ? 'No messages in this channel'
                                : 'Start the conversation',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textTertiary,
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

                        // Debug: Log message direction calculation
                        if (index == 0) {
                          AppLogging.messages(
                            '📨 Message[0]: from=${message.from}, myNodeNum=$myNodeNum, isFromMe=$isFromMe, text="${message.text.substring(0, message.text.length.clamp(0, 20))}"',
                          );
                        }

                        // Get sender info - prefer fresh node lookup, fallback to message's cached info
                        final senderNode = nodes[message.from];
                        final senderName =
                            senderNode?.displayName ??
                            message.senderDisplayName;
                        final senderShortName =
                            senderNode?.shortName ?? message.senderAvatarName;
                        final avatarColor =
                            senderNode?.avatarColor ??
                            message.senderAvatarColor;

                        return _MessageBubble(
                          message: message,
                          isFromMe: isFromMe,
                          senderName: senderName,
                          senderShortName: senderShortName,
                          avatarColor: avatarColor,
                          showSender:
                              widget.type == ConversationType.channel &&
                              !isFromMe,
                          isEncrypted: isEncrypted,
                          isQueued: queuedMessageIds.contains(message.id),
                          channelIndex: widget.type == ConversationType.channel
                              ? widget.channelIndex
                              : null,
                          onRetry: message.isFailed
                              ? () => _retryMessage(message)
                              : null,
                          onPkiFix: message.routingError?.isPkiRelated == true
                              ? () => _showPkiFixSheet(message)
                              : null,
                          onDelete: () => _deleteMessage(message),
                          onSenderTap: senderNode != null && !isFromMe
                              ? () => showNodeDetailsSheet(
                                  context,
                                  senderNode,
                                  false,
                                )
                              : null,
                        );
                      },
                    ),
            ),

            // Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                border: Border(
                  top: BorderSide(color: context.border.withValues(alpha: 0.3)),
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
                          color: context.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bolt,
                          color: context.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.background,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          style: TextStyle(color: context.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            hintStyle: TextStyle(color: context.textTertiary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
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
                    SizedBox(width: 12),
                    // Voice messaging not practical over LoRa due to bandwidth limits
                    // Show send button always
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.accentColor,
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
  final int? channelIndex;
  final VoidCallback? onRetry;
  final VoidCallback? onPkiFix;
  final VoidCallback? onDelete;
  final VoidCallback? onSenderTap;

  const _MessageBubble({
    required this.message,
    required this.isFromMe,
    required this.senderName,
    required this.senderShortName,
    this.avatarColor,
    this.showSender = true,
    this.isEncrypted = true,
    this.isQueued = false,
    this.channelIndex,
    this.onRetry,
    this.onPkiFix,
    this.onDelete,
    this.onSenderTap,
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

  /// Get icon data for message source (only for non-manual sources)
  IconData? _getSourceIcon() {
    switch (message.source) {
      case MessageSource.automation:
        return Icons.auto_awesome;
      case MessageSource.siri:
        return Icons.mic;
      case MessageSource.reaction:
        return Icons.notifications_active;
      case MessageSource.tapback:
        return Icons.thumb_up_alt;
      case MessageSource.manual:
      case MessageSource.unknown:
        return null;
    }
  }

  /// Get label text for message source
  String? _getSourceLabel() {
    switch (message.source) {
      case MessageSource.automation:
        return 'Automation';
      case MessageSource.siri:
        return 'Shortcut';
      case MessageSource.reaction:
        return 'Notification';
      case MessageSource.tapback:
        return 'Tapback';
      case MessageSource.manual:
      case MessageSource.unknown:
        return null;
    }
  }

  /// Get background color for source badge
  Color _getSourceColor() {
    switch (message.source) {
      case MessageSource.automation:
        return const Color(0xFF8B5CF6); // Purple
      case MessageSource.siri:
        return const Color(0xFFFF2D55); // Siri pink/red
      case MessageSource.reaction:
        return const Color(0xFFFF9500); // Orange
      case MessageSource.tapback:
        return const Color(0xFF30D158); // Green
      case MessageSource.manual:
      case MessageSource.unknown:
        return Colors.transparent;
    }
  }

  /// Build the source badge widget
  Widget? _buildSourceBadge() {
    final icon = _getSourceIcon();
    final label = _getSourceLabel();
    if (icon == null || label == null) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getSourceColor().withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final isFailed = message.isFailed;
    final isPending = message.isPending;
    final isDelivered = message.status == MessageStatus.delivered;
    final sourceBadge = _buildSourceBadge();

    if (isFromMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Source badge above message (Shortcut, Automation, etc.)
            // Wrapped in Row to match message bubble alignment
            if (sourceBadge != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: sourceBadge,
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: GestureDetector(
                    onLongPress: () => _showContextMenu(context),
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
                            ? context.accentColor.withValues(alpha: 0.6)
                            : context.accentColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            message.text,
                            style: TextStyle(fontSize: 15, color: Colors.white),
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
                                LoadingIndicator(size: 12),
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
                ),
              ],
            ),
            if (isFailed) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
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
                                color: context.card,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    size: 12,
                                    color: context.accentColor,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.accentColor,
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
                    // Show fix suggestion for PKI-related errors
                    if (message.routingError?.isPkiRelated == true &&
                        onPkiFix != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onPkiFix,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warningYellow.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.warningYellow.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 12,
                                color: AppTheme.warningYellow,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Fix: Refresh Keys',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.warningYellow,
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
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onSenderTap,
                child: NodeAvatar(
                  text: _getSafeShortName(),
                  color: _getAvatarColor(),
                  size: 32,
                ),
              ),
            ),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showContextMenu(context),
              child: Container(
                margin: const EdgeInsets.only(right: 64),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSender) ...[
                      GestureDetector(
                        onTap: onSenderTap,
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getAvatarColor(),
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                    ],
                    Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isEncrypted) ...[
                          Icon(
                            Icons.lock,
                            size: 10,
                            color: context.textTertiary,
                          ),
                          SizedBox(width: 3),
                        ],
                        Text(
                          timeFormat.format(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showMessageContextMenu(
      context,
      message: message,
      isFromMe: isFromMe,
      senderName: senderName,
      channelIndex: channelIndex,
      onDelete: onDelete,
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
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bolt, color: context.accentColor, size: 18),
                ),
                SizedBox(width: 12),
                Text(
                  'Quick Responses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: context.border, height: 1),
          // Responses grid
          Flexible(
            child: responses.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No quick responses configured.\nAdd some in Settings → Quick responses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textSecondary),
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
          // Footer with settings link
          Divider(color: context.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CannedResponsesScreen(),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.settings,
                    size: 16,
                    color: context.textSecondary.withValues(alpha: 0.8),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Configure quick responses in Settings',
                    style: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: context.textSecondary.withValues(alpha: 0.6),
                  ),
                ],
              ),
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
      color: context.background,
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
              style: TextStyle(
                color: context.textPrimary,
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
        SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.border),
          ),
          child: _showKey
              ? SelectableText(
                  base64Key,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.accentColor,
                    fontFamily: AppTheme.fontFamily,
                  ),
                )
              : Text(
                  '•' * 32,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textTertiary.withValues(alpha: 0.5),
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showKey = !_showKey),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: context.border),
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
                        showSuccessSnackBar(context, 'Key copied to clipboard');
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: context.background,
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

/// Popup menu for messaging screen with settings and help
class _MessagingPopupMenu extends ConsumerWidget {
  const _MessagingPopupMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: context.textPrimary),
      tooltip: 'More options',
      color: context.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.border),
      ),
      onSelected: (value) {
        switch (value) {
          case 'settings':
            Navigator.pushNamed(context, '/settings');
          case 'help':
            ref.read(helpProvider.notifier).startTour('message_routing');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'help',
          child: Row(
            children: [
              Icon(Icons.help_outline, color: context.textSecondary, size: 20),
              const SizedBox(width: 12),
              Text('Help', style: TextStyle(color: context.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                color: context.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text('Settings', style: TextStyle(color: context.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filter chip widget for contacts
class _ContactFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  const _ContactFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryBlue;
    final showStatusIndicator = label == 'Online';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.2) : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withValues(alpha: 0.5)
                : context.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator for Online chip
            if (showStatusIndicator) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [chipColor, chipColor.withValues(alpha: 0.6)],
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: chipColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? chipColor : context.textTertiary,
              ),
              SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? chipColor : context.textSecondary,
              ),
            ),
            SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.3)
                    : context.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? chipColor : context.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
