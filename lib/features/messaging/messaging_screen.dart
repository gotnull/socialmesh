// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:socialmesh/features/nodes/node_display_name_resolver.dart';
import '../../core/logging.dart';
import 'package:flutter/material.dart';
import '../../core/safety/lifecycle_mixin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/review_providers.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../models/canned_response.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../utils/snackbar.dart';
import '../../utils/presence_utils.dart';
import '../../providers/presence_providers.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/gradient_border_container.dart';
import '../../core/widgets/ico_help_system.dart';

import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_banner.dart';
import '../../core/widgets/node_avatar.dart';
import '../channels/channel_options_sheet.dart';
import '../../services/messaging/offline_queue_service.dart';
import '../../services/haptic_service.dart';
import '../settings/canned_responses_screen.dart';
import '../settings/device_management_screen.dart';
import '../nodes/nodes_screen.dart';
import '../navigation/main_shell.dart';
import 'widgets/message_context_menu.dart';
import '../../core/widgets/loading_indicator.dart';

/// Conversation type enum
enum ConversationType { channel, directMessage }

/// Contact filter enum
enum ContactFilter { all, favorites, messaged, unread, active }

/// Main messaging screen - shows list of conversations
class MessagingScreen extends ConsumerStatefulWidget {
  /// When true, shows only the body content without AppBar/Scaffold
  /// Used when embedded in tabs
  final bool embedded;

  const MessagingScreen({super.key, this.embedded = false});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen>
    with LifecycleSafeMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  ContactFilter _currentFilter = ContactFilter.all;
  bool _showSectionHeaders = true;

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
    final presenceMap = ref.watch(presenceMapProvider);
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
          presence: presenceConfidenceFor(presenceMap, node),
          lastHeardAge: lastHeardAgeFor(presenceMap, node),
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
              NodeDisplayNameResolver.defaultName(nodeNum),
          shortName: dmInfo.senderShortName,
          avatarColor: dmInfo.senderAvatarColor,
          presence: PresenceConfidence.unknown,
          lastHeardAge: null,
          lastMessage: dmInfo.lastMessage,
          lastMessageTime: dmInfo.lastMessageTime,
          unreadCount: dmInfo.unreadCount,
        ),
      );
    }

    // Sort: favorites first, then unread, then online, then by name
    contacts.sort((a, b) {
      // Favorites first
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      // Unread messages next
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (b.unreadCount > 0 && a.unreadCount == 0) return 1;
      // Then active nodes
      if (a.presence.isActive != b.presence.isActive) {
        return a.presence.isActive ? -1 : 1;
      }
      // Then alphabetically
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    // Calculate filter counts
    final favoritesCount = contacts.where((c) => c.isFavorite).length;
    final messagedCount = contacts.where((c) => c.hasMessages).length;
    final unreadCount = contacts.where((c) => c.unreadCount > 0).length;
    final activeCount = contacts.where((c) => c.presence.isActive).length;

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
      case ContactFilter.active:
        filteredContacts = contacts.where((c) => c.presence.isActive).toList();
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
                    padding: const EdgeInsets.only(left: 16),
                    children: [
                      SectionFilterChip(
                        label: 'All',
                        count: contacts.length,
                        isSelected: _currentFilter == ContactFilter.all,
                        onTap: () =>
                            setState(() => _currentFilter = ContactFilter.all),
                      ),
                      SizedBox(width: 8),
                      SectionFilterChip(
                        label: 'Active',
                        count: activeCount,
                        isSelected: _currentFilter == ContactFilter.active,
                        color: AccentColors.green,
                        onTap: () => setState(
                          () => _currentFilter = ContactFilter.active,
                        ),
                      ),
                      SizedBox(width: 8),
                      SectionFilterChip(
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
                      SectionFilterChip(
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
                      SectionFilterChip(
                        label: 'Favorites',
                        count: favoritesCount,
                        isSelected: _currentFilter == ContactFilter.favorites,
                        icon: Icons.star,
                        color: AppTheme.warningYellow,
                        onTap: () => setState(
                          () => _currentFilter = ContactFilter.favorites,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              // Static toggle at end
              const SizedBox(width: 8),
              SectionHeadersToggle(
                enabled: _showSectionHeaders,
                onToggle: () =>
                    setState(() => _showSectionHeaders = !_showSectionHeaders),
              ),
              const SizedBox(width: 12),
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
              : _buildContactsList(filteredContacts),
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
            actions: const [DeviceStatusButton(), MessagingPopupMenu()],
          ),
          body: bodyContent,
        ),
      ),
    );
  }

  Widget _buildContactsList(List<_Contact> contacts) {
    final animationsEnabled = ref.watch(animationsEnabledProvider);

    if (!_showSectionHeaders) {
      // Simple list without headers
      return ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
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
      );
    }

    // Build grouped list with section headers
    final sections = _groupContactsIntoSections(contacts);
    final nonEmptySections = sections
        .where((s) => s.contacts.isNotEmpty)
        .toList();

    return CustomScrollView(
      slivers: [
        for (
          var sectionIndex = 0;
          sectionIndex < nonEmptySections.length;
          sectionIndex++
        ) ...[
          // Sticky header
          SliverPersistentHeader(
            pinned: true,
            delegate: SectionHeaderDelegate(
              title: nonEmptySections[sectionIndex].title,
              count: nonEmptySections[sectionIndex].contacts.length,
            ),
          ),
          // Section contacts
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final contact = nonEmptySections[sectionIndex].contacts[index];
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
            }, childCount: nonEmptySections[sectionIndex].contacts.length),
          ),
        ],
      ],
    );
  }

  List<_ContactSection> _groupContactsIntoSections(List<_Contact> contacts) {
    final favorites = contacts.where((c) => c.isFavorite).toList();
    final unread = contacts
        .where((c) => !c.isFavorite && c.unreadCount > 0)
        .toList();
    final active = contacts
        .where(
          (c) => !c.isFavorite && c.unreadCount == 0 && c.presence.isActive,
        )
        .toList();
    final inactive = contacts
        .where(
          (c) => !c.isFavorite && c.unreadCount == 0 && !c.presence.isActive,
        )
        .toList();

    return [
      if (favorites.isNotEmpty) _ContactSection('Favorites', favorites),
      if (unread.isNotEmpty) _ContactSection('Unread', unread),
      if (active.isNotEmpty) _ContactSection('Active', active),
      if (inactive.isNotEmpty) _ContactSection('Inactive', inactive),
    ];
  }
}

/// Helper class for contact section grouping
class _ContactSection {
  final String title;
  final List<_Contact> contacts;

  _ContactSection(this.title, this.contacts);
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
  final PresenceConfidence presence;
  final Duration? lastHeardAge;
  final bool isFavorite;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  _Contact({
    required this.nodeNum,
    required this.displayName,
    this.shortName,
    this.avatarColor,
    this.presence = PresenceConfidence.unknown,
    this.lastHeardAge,
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
    final cardContent = Padding(
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
              if (contact.presence.isActive)
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
                      presenceStatusText(
                        contact.presence,
                        contact.lastHeardAge,
                      ),
                  style: TextStyle(
                    fontSize: 14,
                    color: contact.lastMessage != null
                        ? context.textSecondary
                        : (contact.presence.isActive
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
          // Favorite star icon (matches nodes screen position)
          if (contact.isFavorite)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.star, color: AccentColors.yellow, size: 20),
            ),
          Icon(Icons.chevron_right, color: context.textTertiary),
        ],
      ),
    );

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: !contact.isFavorite
            ? BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.border),
              )
            : null,
        child: contact.isFavorite
            ? GradientBorderContainer(
                borderRadius: 12,
                borderWidth: 2,
                accentOpacity: 1.0,
                accentColor: AccentColors.yellow,
                backgroundColor: context.card,
                child: cardContent,
              )
            : cardContent,
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

class _ChatScreenState extends ConsumerState<ChatScreen>
    with LifecycleSafeMixin {
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
      if (mounted) {
        _messageFocusNode.requestFocus();
      }
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    }
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
    _searchController.removeListener(_onSearchChanged);
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

    // Capture navigator before showing sheet for safe dismissal
    final navigator = Navigator.of(context);

    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: _QuickResponsesSheet(
        responses: responses,
        onSelect: (text) {
          navigator.pop();
          // Check mounted before accessing controller or calling methods
          if (mounted) {
            _messageController.text = text;
            _sendMessage();
          }
        },
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Capture all provider references BEFORE any async operations
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final connectionState = ref.read(connectionStateProvider);
    final offlineQueue = ref.read(offlineQueueProvider);
    final protocol = ref.read(protocolServiceProvider);
    final haptics = ref.read(hapticServiceProvider);

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
    messagesNotifier.addMessage(pendingMessage);
    _messageController.clear();

    // Haptic feedback for message send
    haptics.trigger(HapticType.light);

    // Check if device is connected
    final isConnected =
        connectionState.value == DeviceConnectionState.connected;

    if (!isConnected) {
      // Queue message for later sending
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
            // Use captured notifier - safe even if widget disposed
            messagesNotifier.trackPacket(id, messageId);
          },
          source: MessageSource.manual,
        );
      }

      // Check mounted after await before updating state
      if (!mounted) return;

      // Update status to sent with packet ID
      messagesNotifier.updateMessage(
        messageId,
        pendingMessage.copyWith(status: MessageStatus.sent, packetId: packetId),
      );

      // Track message sent for review prompt
      _trackMessageSentForReview();
    } catch (e) {
      // Check mounted after await before updating state
      if (!mounted) return;

      // Update status to failed with error
      messagesNotifier.updateMessage(
        messageId,
        pendingMessage.copyWith(
          status: MessageStatus.failed,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Tracks message sent and triggers review prompt at milestones (10, 50, 100 messages)
  Future<void> _trackMessageSentForReview() async {
    // Capture all provider references BEFORE any async operations
    final reviewServiceAsync = ref.read(appReviewServiceProvider);
    if (!reviewServiceAsync.hasValue) return;
    final reviewService = reviewServiceAsync.value!;

    // Capture context and review prompt before any awaits
    // This avoids ref/context access after await
    final capturedContext = context;
    void promptForReview(String surface) {
      ref.maybePromptForReview(capturedContext, surface: surface);
    }

    final count = await reviewService.recordMessageSent();

    // Prompt at message milestones
    const milestones = [10, 50, 100];
    if (milestones.contains(count) && mounted) {
      final surface = 'message_milestone_$count';

      // Delay to let message UI settle
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        promptForReview(surface);
      }
    }
  }

  Future<void> _retryMessage(Message message) async {
    // Capture all provider references BEFORE any async operations
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final connectionState = ref.read(connectionStateProvider);
    final offlineQueue = ref.read(offlineQueueProvider);
    final protocol = ref.read(protocolServiceProvider);

    // Update to pending, clear error
    messagesNotifier.updateMessage(
      message.id,
      message.copyWith(
        status: MessageStatus.pending,
        errorMessage: null,
        routingError: null,
      ),
    );

    // Check if device is connected
    final isConnected =
        connectionState.value == DeviceConnectionState.connected;

    if (!isConnected) {
      // Queue message for later sending
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
            // Use captured notifier - safe even if widget disposed
            messagesNotifier.trackPacket(id, message.id);
          },
          source: message.source, // Preserve original source
        );
      }

      // Check mounted after await before updating state
      if (!mounted) return;

      messagesNotifier.updateMessage(
        message.id,
        message.copyWith(
          status: MessageStatus.sent,
          errorMessage: null,
          routingError: null,
          packetId: packetId,
        ),
      );
    } catch (e) {
      // Check mounted after await before updating state
      if (!mounted) return;

      messagesNotifier.updateMessage(
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

    // Capture protocol before showing sheet to avoid ref access in async callback
    final protocol = ref.read(protocolServiceProvider);
    // Capture parent context for snackbars (bottom sheet context becomes invalid after pop)
    final parentContext = context;

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
          StatusBanner.warning(
            title:
                message.routingError?.fixSuggestion ??
                'The encryption keys may be out of sync. This can happen when a node has been reset or rolled out of the mesh database.',
          ),
          const SizedBox(height: 20),
          // Request User Info button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(parentContext);
                try {
                  await protocol.requestNodeInfo(message.to);
                  if (mounted) {
                    showGlobalInfoSnackBar(
                      'Requested fresh info from $targetName',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    showGlobalErrorSnackBar('Failed to request info: $e');
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
              label: Text(
                'Request User Info',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Retry message button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(parentContext);
                if (mounted) {
                  _retryMessage(message);
                }
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
              label: Text(
                'Retry Message',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Advanced options link
          TextButton(
            onPressed: () {
              Navigator.pop(parentContext);
              if (mounted) {
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => const DeviceManagementScreen(),
                  ),
                );
              }
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
    // Capture notifier and parent context before showing dialog
    // to avoid ref access in dialog callback after potential dispose
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.card,
        title: Text(
          'Delete Message',
          style: TextStyle(color: dialogContext.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this message? This only removes it locally.',
          style: TextStyle(color: dialogContext.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: dialogContext.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              messagesNotifier.deleteMessage(message.id);
              Navigator.pop(dialogContext);
              if (mounted) {
                showSuccessSnackBar(parentContext, 'Message deleted');
              }
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

  void _showChannelSettings(BuildContext context, WidgetRef ref) {
    final channels = ref.read(channelsProvider);
    final channel = channels.firstWhere(
      (c) => c.index == widget.channelIndex,
      orElse: () =>
          ChannelConfig(index: widget.channelIndex ?? 0, name: '', psk: []),
    );
    showChannelOptionsSheet(
      context,
      channel,
      ref: ref,
      displayTitle: widget.title,
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
                onPressed: () => _showChannelSettings(context, ref),
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
                          textCapitalization: TextCapitalization.sentences,
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white),
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
                // Capture navigator before pop since context becomes invalid after
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
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

/// Popup menu for messaging screen with settings and help
class MessagingPopupMenu extends ConsumerWidget {
  const MessagingPopupMenu({
    super.key,
    this.onAddChannel,
    this.onScanChannel,
    this.isConnected = false,
  });

  final VoidCallback? onAddChannel;
  final VoidCallback? onScanChannel;
  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBarOverflowMenu<String>(
      onSelected: (value) {
        switch (value) {
          case 'add_channel':
            if (onAddChannel != null) onAddChannel!();
            break;
          case 'scan_channel':
            if (onScanChannel != null) onScanChannel!();
            break;
          case 'settings':
            Navigator.pushNamed(context, '/settings');
            break;
          case 'help':
            ref.read(helpProvider.notifier).startTour('message_routing');
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        if (onAddChannel != null) {
          items.add(
            PopupMenuItem(
              value: 'add_channel',
              child: Row(
                children: [
                  Icon(Icons.add, color: context.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Add channel',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }
        if (onScanChannel != null) {
          items.add(
            PopupMenuItem(
              value: 'scan_channel',
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Scan QR code',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }
        items.addAll([
          PopupMenuItem(
            value: 'help',
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: context.textSecondary,
                  size: 20,
                ),
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
        ]);
        return items;
      },
    );
  }
}
