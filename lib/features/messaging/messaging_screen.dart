// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:collection/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:socialmesh/features/nodes/node_display_name_resolver.dart';
import '../../core/logging.dart';
import '../../core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import '../../core/safety/lifecycle_mixin.dart';
import 'package:flutter/services.dart';
import 'dm_channel_resolver.dart';
import 'dm_contacts_provider.dart';
import 'widgets/chat_composer.dart';
import 'widgets/hop_count_chip.dart';
import 'widgets/message_bubble_body.dart';
import 'widgets/messaging_unread_divider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/text_sanitizer.dart';
import '../../utils/time_format.dart';
import 'dart:async';
import '../../providers/app_providers.dart';
import '../../core/constants.dart';
import '../../providers/help_providers.dart';
import '../../providers/review_providers.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../models/tapback.dart';
import '../../models/canned_response.dart';
import '../../core/node_color.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../utils/snackbar.dart';
import '../../utils/presence_utils.dart';
import '../../providers/presence_providers.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/chat_bubble_text.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/jump_to_latest_pill.dart';

import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../core/widgets/status_banner.dart';
import '../../core/widgets/node_avatar.dart';
import '../channels/channel_options_sheet.dart';
import '../../services/messaging/offline_queue_service.dart';
import '../../services/haptic_service.dart';
import '../settings/canned_responses_screen.dart';
import '../settings/device_management_screen.dart';
import '../settings/translation_settings_screen.dart';
import '../nodes/node_quick_actions_sheet.dart';
import '../nodes/nodes_screen.dart';
import '../nodes/role_filter.dart';
import '../navigation/main_shell.dart';
import 'conversation_timeline.dart';
import 'widgets/message_context_menu.dart';
import 'widgets/tapback_widget.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/translation_providers.dart';
import '../../core/widgets/premium_feature_gate.dart';
import '../../services/translation/translation_models.dart';
import '../../services/storage/conversation_read_position.dart';
import '../../services/protocol/protocol_service.dart';
import '../../services/protocol/text_message_payload_budget.dart';
import '../timeline/message_timeline_screen.dart';

/// Conversation type enum
enum ConversationType { channel, directMessage }

/// Contact filter enum
enum ContactFilter { all, favorites, messaged, unread, active }

typedef ConversationFallbackRowBuilder =
    List<ConversationTimelineRow> Function(List<Message> messages);

({
  List<ConversationTimelineRow> rows,
  bool usedFallbackRows,
  int visibleTimelineMessageCount,
})
selectConversationDisplayRows({
  required List<Message> fallbackMessages,
  required ConversationTimelineState? timelineState,
  ConversationFallbackRowBuilder fallbackRowBuilder =
      buildConversationFallbackRows,
}) {
  final visibleTimelineMessageCount =
      timelineState?.rawMessages
          .where((message) => !message.isCanonicalTapback)
          .length ??
      0;
  final shouldUseFallbackRows =
      fallbackMessages.isNotEmpty &&
      (timelineState == null || timelineState.rows.isEmpty);

  return (
    rows: shouldUseFallbackRows
        ? fallbackRowBuilder(fallbackMessages)
        : (timelineState?.rows ?? const <ConversationTimelineRow>[]),
    usedFallbackRows: shouldUseFallbackRows,
    visibleTimelineMessageCount: visibleTimelineMessageCount,
  );
}

List<ConversationTimelineRow> buildConversationFallbackRows(
  List<Message> messages,
) {
  return messages
      .map((message) => ConversationTimelineRow.message(message: message))
      .toList();
}

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
  String _activeRoleFilter = roleFilterAll;
  bool _showSectionHeaders = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _openContactQuickActions(_Contact contact) async {
    final node = ref.read(nodesProvider)[contact.nodeNum];
    if (node == null) {
      AppLogging.nodes(
        '[QuickActions] contact long-press ignored - no node for '
        'nodeNum=${contact.nodeNum}',
      );
      return;
    }
    await showNodeQuickActionsSheet(context, ref, node);
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final presenceMap = ref.watch(presenceMapProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // DM info per node (last message, unread count) is memoized in its
    // own provider so the O(allMessages) scan reruns only when the
    // message list changes, not on every node or presence tick.
    final dmInfoByNode = ref.watch(dmContactInfoProvider);

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
          lastHeard: node.lastHeard,
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
    final now = DateTime.now();
    contacts.sort((a, b) {
      // Favorites first
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      // Unread messages next
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (b.unreadCount > 0 && a.unreadCount == 0) return 1;
      // Then online nodes (heard within 2-hour window)
      final aOnline = PresenceCalculator.isOnline(a.lastHeard, now: now);
      final bOnline = PresenceCalculator.isOnline(b.lastHeard, now: now);
      if (aOnline != bOnline) {
        return aOnline ? -1 : 1;
      }
      // Then alphabetically
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    // Calculate filter counts
    final favoritesCount = contacts.where((c) => c.isFavorite).length;
    final messagedCount = contacts.where((c) => c.hasMessages).length;
    final unreadCount = contacts.where((c) => c.unreadCount > 0).length;
    final activeCount = contacts
        .where((c) => PresenceCalculator.isOnline(c.lastHeard, now: now))
        .length;

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
        filteredContacts = contacts
            .where((c) => PresenceCalculator.isOnline(c.lastHeard, now: now))
            .toList();
        break;
    }

    // Then filter by role — orthogonal to the presence/favorites
    // dimension above. Looks up the live MeshNode by nodeNum so we
    // don't have to copy role onto _Contact.
    if (_activeRoleFilter != roleFilterAll) {
      filteredContacts = filteredContacts.where((c) {
        final node = nodes[c.nodeNum];
        return node?.role == _activeRoleFilter;
      }).toList();
    }

    // Then filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredContacts = filteredContacts.where((c) {
        return c.displayName.toLowerCase().contains(query) ||
            (c.shortName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Build the body content — use CustomScrollView with a pinned sliver
    // header so the search bar + filter chips never overflow on compact
    // screens.
    final textScaler = MediaQuery.textScalerOf(context);

    final bodyContent = CustomScrollView(
      // When embedded inside a TabBarView that is itself inside
      // GlassScaffold's outer CustomScrollView, the inner scroll must:
      //  - use ClampingScrollPhysics to avoid bounce-fighting with the
      //    outer BouncingScrollPhysics (kGlassScrollPhysics),
      //  - set primary: false so it doesn't compete for the
      //    PrimaryScrollController.
      // Without this, a short list (e.g. few contacts) causes cards to
      // stick behind the pinned search header with no way to scroll down.
      // Inner scrollable owns the bounce now that the outer
      // messages container is pinned with ClampingScrollPhysics.
      // Keeps the pinned search/filter chips fixed below the tabs
      // while the contact list bounces on its own overscroll.
      physics: widget.embedded
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : null,
      primary: !widget.embedded,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            hintText: context.l10n.messagingSearchContactsHint,
            textScaler: textScaler,
            rebuildKey: Object.hashAll([
              _currentFilter,
              contacts.length,
              activeCount,
              unreadCount,
              messagedCount,
              favoritesCount,
              _showSectionHeaders,
            ]),
            trailingControls: [
              SectionHeadersToggle(
                enabled: _showSectionHeaders,
                onToggle: () =>
                    setState(() => _showSectionHeaders = !_showSectionHeaders),
              ),
            ],
            filterChips: [
              StatusFilterChip(
                label: context.l10n.messagingFilterAll,
                count: contacts.length,
                isSelected: _currentFilter == ContactFilter.all,
                onTap: () => setState(() => _currentFilter = ContactFilter.all),
              ),
              StatusFilterChip(
                label: context.l10n.messagingFilterOnline,
                count: activeCount,
                isSelected: _currentFilter == ContactFilter.active,
                color: AccentColors.green,
                onTap: () =>
                    setState(() => _currentFilter = ContactFilter.active),
              ),
              StatusFilterChip(
                label: context.l10n.messagingFilterUnread,
                count: unreadCount,
                isSelected: _currentFilter == ContactFilter.unread,
                icon: Icons.mark_email_unread_outlined,
                color: AccentColors.red,
                onTap: () =>
                    setState(() => _currentFilter = ContactFilter.unread),
              ),
              StatusFilterChip(
                label: context.l10n.messagingFilterMessaged,
                count: messagedCount,
                isSelected: _currentFilter == ContactFilter.messaged,
                icon: Icons.chat_bubble_outline,
                color: AppTheme.primaryBlue,
                onTap: () =>
                    setState(() => _currentFilter = ContactFilter.messaged),
              ),
              StatusFilterChip(
                label: context.l10n.messagingFilterFavorites,
                count: favoritesCount,
                isSelected: _currentFilter == ContactFilter.favorites,
                icon: Icons.star,
                color: AppTheme.warningYellow,
                onTap: () =>
                    setState(() => _currentFilter = ContactFilter.favorites),
              ),
            ],
          ),
        ),
        // Role filter chip row (orthogonal to the presence chips above).
        // Hides itself entirely when only one role is present in the
        // mesh, so small-mesh users see no extra chrome.
        SliverToBoxAdapter(
          child: RoleFilterChipRow(
            nodes: nodes.values,
            selectedRole: _activeRoleFilter,
            source: 'contacts',
            onRoleSelected: (role) => setState(() => _activeRoleFilter = role),
          ),
        ),
        // Contacts list (or empty state)
        if (filteredContacts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
                    ),
                    child: Icon(
                      Icons.people_outline,
                      size: 40,
                      color: context.textTertiary,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing24),
                  Text(
                    _searchQuery.isNotEmpty
                        ? context.l10n.messagingNoContactsMatchSearch(
                            _searchQuery,
                          )
                        : _currentFilter != ContactFilter.all
                        ? context.l10n.messagingNoFilteredContacts(
                            _currentFilter.name,
                          )
                        : context.l10n.messagingNoContactsYet,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.textSecondary,
                    ),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    SizedBox(height: AppTheme.spacing8),
                    Text(
                      context.l10n.messagingContactsDiscoveredHint,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing12),
                    TextButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      child: Text(context.l10n.messagingClearSearch),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ..._buildContactSlivers(filteredContacts),
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
        child: GlassScaffold(
          resizeToAvoidBottomInset: false,
          leading: const HamburgerMenuButton(),
          centerTitle: true,
          titleWidget: Text(
            contacts.isNotEmpty
                ? context.l10n.messagingContactsTitleWithCount(contacts.length)
                : context.l10n.messagingContactsTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          actions: const [DeviceStatusButton(), MessagingPopupMenu()],
          // Use hasScrollBody: true because bodyContent is a CustomScrollView.
          // hasScrollBody: false would force intrinsic dimension computation
          // which CustomScrollView cannot provide, causing a null check crash
          // in RenderViewportBase.layoutChildSequence.
          slivers: [
            SliverFillRemaining(hasScrollBody: true, child: bodyContent),
          ],
        ),
      ),
    );
  }

  /// Returns slivers for the contacts list, suitable for embedding in the
  /// top-level [CustomScrollView].
  List<Widget> _buildContactSlivers(List<_Contact> contacts) {
    final animationsEnabled = ref.watch(animationsEnabledProvider);

    if (!_showSectionHeaders) {
      // Simple flat list
      return [
        SliverPadding(
          padding: const EdgeInsets.only(top: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
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
                  onLongPress: () => _openContactQuickActions(contact),
                ),
              );
            }, childCount: contacts.length),
          ),
        ),
      ];
    }

    // Grouped list with section headers
    final sections = _groupContactsIntoSections(contacts);
    final nonEmptySections = sections
        .where((s) => s.contacts.isNotEmpty)
        .toList();

    return [
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
                onLongPress: () => _openContactQuickActions(contact),
              ),
            );
          }, childCount: nonEmptySections[sectionIndex].contacts.length),
        ),
      ],
    ];
  }

  List<_ContactSection> _groupContactsIntoSections(List<_Contact> contacts) {
    final now = DateTime.now();
    final favorites = contacts.where((c) => c.isFavorite).toList();
    final unread = contacts
        .where((c) => !c.isFavorite && c.unreadCount > 0)
        .toList();
    final online = contacts
        .where(
          (c) =>
              !c.isFavorite &&
              c.unreadCount == 0 &&
              PresenceCalculator.isOnline(c.lastHeard, now: now),
        )
        .toList();
    final offline = contacts
        .where(
          (c) =>
              !c.isFavorite &&
              c.unreadCount == 0 &&
              !PresenceCalculator.isOnline(c.lastHeard, now: now),
        )
        .toList();

    return [
      if (favorites.isNotEmpty)
        _ContactSection(context.l10n.messagingSectionFavorites, favorites),
      if (unread.isNotEmpty)
        _ContactSection(context.l10n.messagingSectionUnread, unread),
      if (online.isNotEmpty)
        _ContactSection(context.l10n.messagingSectionActive, online),
      if (offline.isNotEmpty)
        _ContactSection(context.l10n.messagingSectionInactive, offline),
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
/// Contact model representing a messageable node
class _Contact {
  final int nodeNum;
  final String displayName;
  final String? shortName;
  final int? avatarColor;
  final PresenceConfidence presence;
  final Duration? lastHeardAge;
  final DateTime? lastHeard;
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
    this.lastHeard,
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
  final VoidCallback? onLongPress;

  const _ContactTile({
    required this.contact,
    required this.onTap,
    this.onLongPress,
  });

  Color _blendColor(BuildContext context) {
    if (contact.isFavorite) return AppTheme.warningYellow;
    switch (contact.presence) {
      case PresenceConfidence.active:
        return AccentColors.green;
      case PresenceConfidence.fading:
      case PresenceConfidence.stale:
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final blendColor = _blendColor(context);
    final cardContent = Padding(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      child: Row(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              NodeAvatar(
                text: contact.shortName ?? safeTruncate(contact.displayName, 2),
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
          SizedBox(width: AppTheme.spacing12),
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
                      SizedBox(width: AppTheme.spacing8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.accentColor,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius10,
                          ),
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
                SizedBox(height: AppTheme.spacing4),
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
          const SizedBox(width: AppTheme.spacing8),
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
      onLongPress: onLongPress,
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Stack(
            children: [
              // Layer 1: Flat card surface, matches the canonical
              // settings tile so the bulk of the card reads as neutral.
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
              ),
              // Layer 2: Soft-light category tint. Composites blendColor
              // into the surface via BlendMode.softLight so saturated
              // states (favorite / active) pick up a subtle hue while
              // the inactive gray collapses to no visible change.
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: blendColor.withValues(alpha: 0.5),
                      backgroundBlendMode: BlendMode.softLight,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                ),
              ),
              // Layer 3: Category-coloured border. blendColor encodes
              // favorite / active / inactive.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(color: blendColor),
                    ),
                  ),
                ),
              ),
              // Layer 4: Content
              cardContent,
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

class _ChatScreenState extends ConsumerState<ChatScreen>
    with LifecycleSafeMixin, WidgetsBindingObserver {
  static const double _defaultRestoreAlignment = 0.88;
  static const double _latestJumpAlignment = 0.88;
  static const double _fullyVisibleTrailingEdge = 1.0;
  static const double _trailingEdgeVisibilityTolerance = 0.001;
  static const double _leadingEdgeVisibilityTolerance = 0.001;
  static const double _nearLatestTrailingEdgeThreshold = 1.12;
  static const int _olderLoadPrefetchIndexThreshold = 4;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final ItemScrollController _timelineScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _isSearching = false;
  String _searchQuery = '';
  bool _hasAppliedInitialRestore = false;
  bool _isApplyingInitialRestore = false;
  bool _showJumpToLatest = false;
  bool _olderLoadInFlight = false;

  /// Tracks the currently highlighted message (for quote-tap scroll).
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  Timer? _saveReadPositionTimer;
  ConversationTimelineQuery? _activeTimelineQuery;
  ConversationTimelineController? _timelineController;
  ConversationReadPosition? _lastPersistedReadPosition;
  List<ConversationTimelineRow> _currentDisplayRows = const [];

  /// Id of the newest message rendered on the previous frame. Used to detect
  /// a freshly-arrived message in build() so we can auto-scroll when the user
  /// is parked at the bottom. Null until the first populated frame.
  String? _lastSeenLatestMessageId;

  /// Tracks which message IDs have inline technical info expanded.
  final Set<String> _expandedTechInfoIds = {};

  /// The message being replied to, or null if not replying.
  Message? _replyingTo;

  /// Unread count snapshot captured at chat-open time before
  /// `_markAsRead` flips the per-message `read` flags. Stays static for
  /// the screen's lifetime so the "New messages" divider doesn't migrate
  /// as more inbound messages arrive during the session. Session-only —
  /// resets to 0 the next time the screen mounts.
  int _initialUnreadCount = 0;

  ProviderSubscription<AsyncValue<OperationalReadiness>>?
  _readinessAutoResendSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _itemPositionsListener.itemPositions.addListener(
      _onTimelineViewportChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Do not auto-focus the composer on open. Opening a conversation is
        // a read action far more often than a reply, and popping the keyboard
        // shrinks the message area and forces a "Jump to latest" jump. Focus
        // is requested only on an explicit tap or when starting a reply.
        _captureInitialUnreadCount();
        _markAsRead();
      }
    });
    _searchController.addListener(_onSearchChanged);

    // When Meshtastic readiness transitions to `ready`, auto-resend any
    // messages that previously failed because the protocol wasn't ready
    // (errorMessage == txBlockedNotReady). User taps Send once during the
    // handshake window; we resend automatically when the radio is ready.
    _readinessAutoResendSub = ref
        .listenManual<AsyncValue<OperationalReadiness>>(
          meshtasticReadinessProvider,
          (previous, next) {
            final prev = previous?.asData?.value;
            final curr = next.asData?.value;
            if (prev != OperationalReadiness.ready &&
                curr == OperationalReadiness.ready) {
              _resendReadinessBlockedMessages();
            }
          },
        );
  }

  void _resendReadinessBlockedMessages() {
    if (!mounted) return;
    final sentinel = context.l10n.txBlockedNotReady;
    final blocked = ref
        .read(messagesProvider)
        .where(
          (m) => m.status == MessageStatus.failed && m.errorMessage == sentinel,
        )
        .toList();
    if (blocked.isEmpty) return;
    AppLogging.messages(
      '📤 AUTO_RESEND readiness=ready, resending ${blocked.length} '
      'readiness-blocked message(s)',
    );
    for (final msg in blocked) {
      AppLogging.messages(
        '📤 AUTO_RESEND triggering retry for messageId=${msg.id}',
      );
      _retryMessage(msg);
    }
  }

  /// Snapshot the unread message count for this conversation BEFORE
  /// `_markAsRead` clears the per-message `read` flags. Filters mirror
  /// `MessagesNotifier.markConversationAsRead` / `markChannelAsRead`
  /// exactly so the count matches what the next call will flip.
  void _captureInitialUnreadCount() {
    final messages = ref.read(messagesProvider);
    int count = 0;
    if (widget.type == ConversationType.directMessage &&
        widget.nodeNum != null) {
      final nodeNum = widget.nodeNum!;
      count = messages
          .where((m) => m.received && m.from == nodeNum && !m.read)
          .length;
    } else if (widget.type == ConversationType.channel &&
        widget.channelIndex != null) {
      final channelIndex = widget.channelIndex!;
      count = messages
          .where(
            (m) =>
                m.received &&
                m.isBroadcast &&
                m.channel == channelIndex &&
                !m.read,
          )
          .length;
    }
    if (count > 0) {
      setState(() => _initialUnreadCount = count);
    }
  }

  /// Mark all messages in this conversation as read.
  void _markAsRead() {
    final messagesNotifier = ref.read(messagesProvider.notifier);
    if (widget.type == ConversationType.directMessage &&
        widget.nodeNum != null) {
      messagesNotifier.markConversationAsRead(widget.nodeNum!);
    } else if (widget.type == ConversationType.channel &&
        widget.channelIndex != null) {
      messagesNotifier.markChannelAsRead(widget.channelIndex!);
    }
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
    unawaited(_persistReadingPositionNow());
    WidgetsBinding.instance.removeObserver(this);
    _itemPositionsListener.itemPositions.removeListener(
      _onTimelineViewportChanged,
    );
    _highlightTimer?.cancel();
    _saveReadPositionTimer?.cancel();
    _readinessAutoResendSub?.close();
    _searchController.removeListener(_onSearchChanged);
    _messageController.dispose();
    _searchController.dispose();
    _messageFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_persistReadingPositionNow());
    }
  }

  void _resetTimelineState(ConversationTimelineQuery query) {
    _activeTimelineQuery = query;
    _hasAppliedInitialRestore = false;
    _isApplyingInitialRestore = false;
    _showJumpToLatest = false;
    _olderLoadInFlight = false;
    _lastPersistedReadPosition = null;
    _currentDisplayRows = const [];
    _lastSeenLatestMessageId = null;
  }

  void _onTimelineViewportChanged() {
    if (!mounted || _currentDisplayRows.isEmpty) {
      return;
    }

    if (_hasAppliedInitialRestore && !_isApplyingInitialRestore) {
      final shouldShowJump =
          !_isSearching &&
          _currentDisplayRows.length > 1 &&
          !_isNearLatest(_currentDisplayRows);
      if (shouldShowJump != _showJumpToLatest && mounted) {
        setState(() => _showJumpToLatest = shouldShowJump);
      }
    }

    if (_hasAppliedInitialRestore &&
        !_isApplyingInitialRestore &&
        (!_isSearching || _searchQuery.isEmpty)) {
      _scheduleReadPositionSave();
      unawaited(_maybeLoadOlderHistory());
    }
  }

  void _scheduleReadPositionSave() {
    _saveReadPositionTimer?.cancel();
    _saveReadPositionTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_persistReadingPositionNow()),
    );
  }

  Future<void> _persistReadingPositionNow() async {
    final query = _activeTimelineQuery;
    final timelineController = _timelineController;
    if (query == null ||
        timelineController == null ||
        !query.hasStableConversationKey) {
      return;
    }
    if (_currentDisplayRows.isEmpty) return;
    if (_isSearching && _searchQuery.isNotEmpty) return;

    final captured = _captureReadPosition(query);
    if (captured == null ||
        _isSameReadPosition(_lastPersistedReadPosition, captured)) {
      return;
    }

    await timelineController.saveReadPosition(query, captured);
    _lastPersistedReadPosition = captured;
  }

  ConversationReadPosition? _captureReadPosition(
    ConversationTimelineQuery query,
  ) {
    final visiblePositions = _sortedVisiblePositions();
    if (visiblePositions.isEmpty) return null;

    ItemPosition? candidate;
    for (final position in visiblePositions) {
      final row = _currentDisplayRows[position.index];
      if (row.message == null) continue;
      final fullyVisible =
          position.itemLeadingEdge >= 0 && position.itemTrailingEdge <= 1;
      if (!fullyVisible) continue;
      candidate = position;
    }

    candidate ??= visiblePositions.lastWhereOrNull((position) {
      final row = _currentDisplayRows[position.index];
      return row.message != null;
    });
    if (candidate == null) return null;

    final message = _currentDisplayRows[candidate.index].message;
    if (message == null) return null;

    return ConversationReadPosition(
      conversationKey: query.stableConversationKey!,
      anchorMessageId: message.id,
      anchorTimestamp: message.timestamp,
      anchorAlignment: candidate.itemLeadingEdge.clamp(0.0, 1.0),
      wasNearLatest: _isNearLatest(_currentDisplayRows),
      updatedAt: DateTime.now(),
    );
  }

  bool _isSameReadPosition(
    ConversationReadPosition? previous,
    ConversationReadPosition current,
  ) {
    if (previous == null) return false;
    final previousAlignment =
        previous.anchorAlignment ?? _defaultRestoreAlignment;
    final currentAlignment =
        current.anchorAlignment ?? _defaultRestoreAlignment;
    return previous.conversationKey == current.conversationKey &&
        previous.anchorMessageId == current.anchorMessageId &&
        previous.anchorTimestamp == current.anchorTimestamp &&
        previous.wasNearLatest == current.wasNearLatest &&
        (previousAlignment - currentAlignment).abs() < 0.01;
  }

  List<ItemPosition> _sortedVisiblePositions() {
    final positions =
        _itemPositionsListener.itemPositions.value
            .where(
              (position) =>
                  position.index >= 0 &&
                  position.index < _currentDisplayRows.length,
            )
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    return positions;
  }

  bool _isNearLatest(List<ConversationTimelineRow> displayRows) {
    if (displayRows.isEmpty) return true;
    final latestIndex = displayRows.length - 1;
    for (final position in _sortedVisiblePositions()) {
      if (position.index == latestIndex) {
        return position.itemTrailingEdge <= _nearLatestTrailingEdgeThreshold;
      }
    }
    return false;
  }

  ItemPosition? _visiblePositionForIndex(int index) {
    for (final position in _sortedVisiblePositions()) {
      if (position.index == index) {
        return position;
      }
    }
    return null;
  }

  bool _isTrailingEdgeFullyVisible(ItemPosition position) {
    return position.itemTrailingEdge <=
        _fullyVisibleTrailingEdge + _trailingEdgeVisibilityTolerance;
  }

  bool _isLeadingEdgeFullyVisible(ItemPosition position) {
    return position.itemLeadingEdge >= -_leadingEdgeVisibilityTolerance;
  }

  bool _isItemFullyVisible(ItemPosition position) {
    return _isLeadingEdgeFullyVisible(position) &&
        _isTrailingEdgeFullyVisible(position);
  }

  double _alignmentForFullVisibility(ItemPosition position) {
    final itemExtent = position.itemTrailingEdge - position.itemLeadingEdge;
    return (_fullyVisibleTrailingEdge - itemExtent).clamp(0.0, 1.0);
  }

  double _correctedAlignmentForVisibility(ItemPosition position) {
    if (!_isLeadingEdgeFullyVisible(position)) {
      return 0.0;
    }
    return _alignmentForFullVisibility(position);
  }

  Future<void> _maybeLoadOlderHistory() async {
    if (!mounted || _olderLoadInFlight || _isApplyingInitialRestore) {
      return;
    }
    final query = _activeTimelineQuery;
    final timelineController = _timelineController;
    if (query == null ||
        timelineController == null ||
        !query.hasStableConversationKey) {
      return;
    }

    final timelineState = ref
        .read(conversationTimelineStateProvider(query))
        ?.asData
        ?.value;
    if (timelineState == null ||
        timelineState.isLoadingOlder ||
        !timelineState.hasMoreOlder) {
      return;
    }

    final visiblePositions = _sortedVisiblePositions();
    if (visiblePositions.isEmpty ||
        visiblePositions.first.index > _olderLoadPrefetchIndexThreshold) {
      return;
    }

    final anchor = visiblePositions.firstWhereOrNull(
      (position) => _currentDisplayRows[position.index].message != null,
    );
    _olderLoadInFlight = true;
    try {
      final added = await timelineController.loadOlder(query);
      if (!mounted || added <= 0 || anchor == null) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_timelineScrollController.isAttached) {
          return;
        }
        _timelineScrollController.jumpTo(
          index: anchor.index + added,
          alignment: anchor.itemLeadingEdge.clamp(0.0, 1.0),
        );
      });
    } finally {
      _olderLoadInFlight = false;
    }
  }

  void _scheduleTimelineInitialization(ConversationTimelineQuery query) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeTimelineQuery != query) {
        return;
      }
      final timelineController = _timelineController;
      if (timelineController == null) {
        return;
      }
      unawaited(timelineController.ensureInitialized(query));
    });
  }

  void _scheduleInitialRestore(ConversationTimelineQuery query) {
    if (_hasAppliedInitialRestore || _isApplyingInitialRestore) {
      return;
    }
    _isApplyingInitialRestore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_applyInitialRestore(query));
    });
  }

  Future<void> _applyInitialRestore(ConversationTimelineQuery query) async {
    ConversationRestoreTarget target = const ConversationRestoreTarget.latest();
    try {
      final timelineController = _timelineController;
      if (timelineController == null) {
        return;
      }
      target = await timelineController.resolveInitialRestoreTarget(query);
      if (!mounted || _activeTimelineQuery != query) {
        return;
      }

      if (target.scrollsToMessage) {
        await _scrollToMessage(
          query,
          messageId: target.messageId!,
          alignment: target.alignment,
          animate: false,
        );
      } else {
        await _scrollToLatest(query, animate: false);
      }
    } finally {
      if (mounted && _activeTimelineQuery == query) {
        setState(() {
          _hasAppliedInitialRestore = true;
          _isApplyingInitialRestore = false;
          _showJumpToLatest = target.hasNewerMessages;
        });
      }
    }
  }

  Future<void> _scrollToLatest(
    ConversationTimelineQuery query, {
    required bool animate,
    int attempt = 0,
  }) async {
    if (!mounted || _activeTimelineQuery != query) {
      return;
    }

    final latestIndex = _currentDisplayRows.length - 1;
    if (!_timelineScrollController.isAttached || latestIndex < 0) {
      if (attempt < 6) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || _activeTimelineQuery != query) {
          return;
        }
        await _scrollToLatest(query, animate: animate, attempt: attempt + 1);
      }
      return;
    }

    final latestPosition = _visiblePositionForIndex(latestIndex);
    final targetAlignment = latestPosition == null
        ? _latestJumpAlignment
        : _alignmentForFullVisibility(latestPosition);

    if (animate) {
      await _timelineScrollController.scrollTo(
        index: latestIndex,
        alignment: targetAlignment,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _timelineScrollController.jumpTo(
        index: latestIndex,
        alignment: targetAlignment,
      );
    }

    if (!mounted || _activeTimelineQuery != query) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _activeTimelineQuery != query) {
      return;
    }

    final refreshedPosition = _visiblePositionForIndex(latestIndex);
    if (refreshedPosition == null ||
        _isTrailingEdgeFullyVisible(refreshedPosition)) {
      return;
    }

    if (attempt < 6) {
      await _scrollToLatest(query, animate: false, attempt: attempt + 1);
    }
  }

  void _scheduleScrollToMessage(
    ConversationTimelineQuery query, {
    required String messageId,
    required double alignment,
    required bool animate,
    bool highlight = false,
    int attempt = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _scrollToMessage(
          query,
          messageId: messageId,
          alignment: alignment,
          animate: animate,
          highlight: highlight,
          attempt: attempt,
        ),
      );
    });
  }

  Future<void> _scrollToMessage(
    ConversationTimelineQuery query, {
    required String messageId,
    required double alignment,
    required bool animate,
    bool highlight = false,
    int attempt = 0,
  }) async {
    if (!mounted || _activeTimelineQuery != query) {
      return;
    }

    final targetIndex = _displayIndexForMessageId(messageId);
    if (!_timelineScrollController.isAttached || targetIndex == null) {
      if (attempt < 6) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || _activeTimelineQuery != query) {
          return;
        }
        await _scrollToMessage(
          query,
          messageId: messageId,
          alignment: alignment,
          animate: animate,
          highlight: highlight,
          attempt: attempt + 1,
        );
      }
      return;
    }

    final clampedAlignment = alignment.clamp(0.0, 1.0);
    if (animate) {
      await _timelineScrollController.scrollTo(
        index: targetIndex,
        alignment: clampedAlignment,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _timelineScrollController.jumpTo(
        index: targetIndex,
        alignment: clampedAlignment,
      );
    }

    if (!mounted || _activeTimelineQuery != query) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _activeTimelineQuery != query) {
      return;
    }

    final refreshedPosition = _visiblePositionForIndex(targetIndex);
    if (refreshedPosition != null &&
        !_isItemFullyVisible(refreshedPosition) &&
        attempt < 6) {
      await _scrollToMessage(
        query,
        messageId: messageId,
        alignment: _correctedAlignmentForVisibility(refreshedPosition),
        animate: false,
        highlight: highlight,
        attempt: attempt + 1,
      );
      return;
    }

    if (highlight && mounted) {
      _highlightTimer?.cancel();
      setState(() => _highlightedMessageId = messageId);
      _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _highlightedMessageId = null);
        }
      });
    }
  }

  int? _displayIndexForMessageId(String messageId) {
    for (var index = 0; index < _currentDisplayRows.length; index++) {
      final message = _currentDisplayRows[index].message;
      if (message?.id == messageId) {
        return index;
      }
    }
    return null;
  }

  Future<void> _scrollToQuotedMessage(int replyId) async {
    final query = _activeTimelineQuery;
    final timelineController = _timelineController;
    if (query == null || timelineController == null) return;

    final messageId = await timelineController.ensureMessageWithPacketIdLoaded(
      query,
      replyId,
    );
    if (!mounted || _activeTimelineQuery != query || messageId == null) {
      return;
    }

    _scheduleScrollToMessage(
      query,
      messageId: messageId,
      alignment: 0.4,
      animate: true,
      highlight: true,
    );
  }

  Future<void> _jumpToLatest() async {
    final query = _activeTimelineQuery;
    if (query == null) return;

    await _scrollToLatest(query, animate: true);
    if (mounted) {
      setState(() => _showJumpToLatest = false);
    }
  }

  void _setReplyTo(Message message) {
    setState(() => _replyingTo = message);
    // Defer focus until after the modal context menu's pop animation
    // settles. Calling requestFocus synchronously inside the menu's
    // onTap loses to the modal route's focus restoration on dismiss,
    // so the keyboard never appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messageFocusNode.requestFocus();
    });
  }

  void _clearReply() {
    setState(() => _replyingTo = null);
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
    final text = _messageController.text;
    if (!TextMessagePayloadSizer.hasSendableContent(text)) return;

    final replyPacketId = _replyingTo?.packetId;
    final textPayloadBudget = TextMessagePayloadSizer.standard(
      replyId: replyPacketId,
    ).measure(text);
    if (!textPayloadBudget.fitsInPacket) {
      showErrorSnackBar(
        context,
        context.l10n.messagingComposerTooLong(
          textPayloadBudget.utf8Bytes,
          textPayloadBudget.maxUtf8Bytes,
        ),
      );
      return;
    }

    // Capture all provider references BEFORE any async operations
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final connectionState = ref.read(connectionStateProvider);
    final offlineQueue = ref.read(offlineQueueProvider);
    final lastDeviceProtocol = ref
        .read(settingsServiceProvider)
        .asData
        ?.value
        .lastDeviceProtocol;
    AppLogging.messages(
      '📤 SEND_TAP type=${widget.type} channel=${widget.channelIndex} '
      'nodeNum=${widget.nodeNum} lastProtocol=$lastDeviceProtocol '
      'connectionState=${connectionState.asData?.value} '
      'protocolReadiness=${ref.read(protocolServiceProvider).readiness} '
      'configurationComplete=${ref.read(protocolServiceProvider).configurationComplete} '
      'transportConnected=${ref.read(protocolServiceProvider).isConnected}',
    );
    final protocol = ref.read(protocolServiceProvider);
    final haptics = ref.read(hapticServiceProvider);

    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final to = widget.type == ConversationType.channel
        ? 0xFFFFFFFF
        : widget.nodeNum!;
    // For DMs, route through the iOS-parity resolver (always channel 0,
    // attaches the recipient's curve25519 public key when known so the
    // firmware encrypts with PKI rather than the channel PSK). For
    // channel broadcasts, the channel index is fixed by the source tab.
    final dmResolution =
        widget.type == ConversationType.directMessage && widget.nodeNum != null
        ? resolveDmChannel(
            destinationNodeId: widget.nodeNum!,
            destinationNode: nodes[widget.nodeNum!],
          )
        : null;
    final channel = widget.type == ConversationType.channel
        ? widget.channelIndex ?? 0
        : dmResolution?.channel ?? 0;
    final pkiPublicKey = dmResolution?.publicKey;
    // Match official Meshtastic behaviour: wantAck=true for ALL user messages.
    // The firmware uses this for reliable delivery tracking. Channel broadcasts
    // won't receive explicit ACKs, but the firmware still benefits from the
    // consistent flag (implicit ACK via relays, unified retry logic, etc.).
    const wantAck = true;

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
      replyId: replyPacketId,
      senderLongName: myNode?.longName,
      senderShortName: myNode?.shortName,
      senderAvatarColor: myNode?.avatarColor,
    );

    // Add to messages immediately for optimistic UI
    messagesNotifier.addMessage(pendingMessage);
    final activeQuery = _activeTimelineQuery;
    final hasActiveSearchFilter = _isSearching && _searchQuery.isNotEmpty;
    if (activeQuery != null && !hasActiveSearchFilter) {
      if (mounted && _showJumpToLatest) {
        setState(() => _showJumpToLatest = false);
      }
      _scheduleScrollToMessage(
        activeQuery,
        messageId: messageId,
        alignment: _latestJumpAlignment,
        animate: true,
      );
    }
    _messageController.clear();
    _clearReply();

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
        showInfoSnackBar(context, context.l10n.messagingMessageQueuedOffline);
      }
      return;
    }

    AppLogging.messages(
      '📤 SEND_DISPATCH messageId=$messageId type=${widget.type} '
      'to=0x${to.toRadixString(16)} channel=$channel '
      'textBytes=${textPayloadBudget.utf8Bytes} wantAck=$wantAck '
      'protocolReadiness=${protocol.readiness} '
      'configurationComplete=${protocol.configurationComplete}',
    );

    try {
      int packetId;

      if (widget.type == ConversationType.channel) {
        // Track the broadcast packet so the firmware's implicit mesh ack (a
        // self-addressed Routing packet emitted when the radio hears its own
        // broadcast rebroadcast by another node) flips the bubble from "sent
        // to radio" to "heard by mesh". Pre-track before the send so the ack
        // cannot race ahead of tracking setup. sentAt stays null below, which
        // keeps the broadcast out of the DM unconfirmed/auto-retry coordinator.
        packetId = await protocol.sendMessageWithPreTracking(
          text: text,
          to: 0xFFFFFFFF, // Broadcast to channel
          channel: widget.channelIndex ?? 0,
          wantAck: true,
          messageId: messageId,
          onPacketIdGenerated: (id) {
            // Use captured notifier - safe even if widget disposed
            messagesNotifier.trackPacket(id, messageId);
          },
          source: MessageSource.manual,
          replyId: replyPacketId,
        );
      } else {
        // Pre-generate packet ID and track BEFORE sending to avoid race condition
        // where ACK arrives before tracking is set up.
        //
        // Channel + pkiPublicKey come from the iOS-parity resolver:
        // channel is always 0 for DMs (matches
        // `MessageDestination.channelNum` in
        // `meshtastic-ios/Meshtastic/Enums/MessageDestination.swift:13-18`)
        // and the public key (when known) attaches `pki_encrypted=true`
        // on the wire (matches `AccessoryManager+ToRadio.swift:327-329`).
        packetId = await protocol.sendMessageWithPreTracking(
          text: text,
          to: widget.nodeNum!,
          channel: dmResolution?.channel ?? 0,
          wantAck: true,
          messageId: messageId,
          onPacketIdGenerated: (id) {
            // Use captured notifier - safe even if widget disposed
            messagesNotifier.trackPacket(id, messageId);
          },
          source: MessageSource.manual,
          replyId: replyPacketId,
          pkiPublicKey: pkiPublicKey,
        );
      }

      // Check mounted after await before updating state
      if (!mounted) return;

      // Read current state — ACK may have arrived during the async send,
      // in which case the message is already delivered.  Build the update
      // from the *current* message, not the stale pendingMessage, so we
      // never overwrite delivered status.
      final currentMessages = ref.read(messagesProvider);
      final currentMsg = currentMessages.firstWhereOrNull(
        (m) => m.id == messageId,
      );
      if (currentMsg == null || currentMsg.status == MessageStatus.delivered) {
        AppLogging.messages(
          '📤 SEND_OK messageId=$messageId packetId=$packetId '
          'currentStatus=${currentMsg?.status} (skip-update)',
        );
        _trackMessageSentForReview();
        return;
      }

      AppLogging.messages(
        '📤 SEND_OK messageId=$messageId packetId=$packetId '
        'status=pending->sent',
      );
      // Update status to sent with packet ID and sentAt for DM timeout tracking
      messagesNotifier.updateMessage(
        messageId,
        currentMsg.copyWith(
          status: MessageStatus.sent,
          packetId: packetId,
          sentAt: widget.type == ConversationType.directMessage
              ? DateTime.now()
              : null,
        ),
      );

      // Track message sent for review prompt
      _trackMessageSentForReview();
    } catch (e, st) {
      AppLogging.messages(
        '📤 SEND_FAIL messageId=$messageId error=$e '
        'protocolReadiness=${protocol.readiness} '
        'configurationComplete=${protocol.configurationComplete} '
        'transportConnected=${protocol.isConnected}',
      );
      AppLogging.messages('📤 SEND_FAIL_STACK $st');

      // Check mounted after await before updating state
      if (!mounted) return;

      // Surface the readiness-gate snackbar when applicable; either way, mark
      // the optimistic bubble failed so it cannot spin forever in `pending`.
      // Use the localised readiness message for the failed-state error text
      // when that was the cause, instead of leaking the raw StateError.
      final isReadinessBlocked = maybeShowTxBlockedSnackBar(context, e);
      AppLogging.messages(
        '📤 SEND_FAIL_KIND messageId=$messageId '
        'readinessBlocked=$isReadinessBlocked',
      );
      messagesNotifier.updateMessage(
        messageId,
        pendingMessage.copyWith(
          status: MessageStatus.failed,
          errorMessage: isReadinessBlocked
              ? context.l10n.txBlockedNotReady
              : e.toString(),
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

    AppLogging.messages(
      '📤 RETRY_TAP messageId=${message.id} isBroadcast=${message.isBroadcast} '
      'channel=${message.channel} to=0x${message.to.toRadixString(16)} '
      'connectionState=${connectionState.asData?.value} '
      'protocolReadiness=${protocol.readiness} '
      'configurationComplete=${protocol.configurationComplete} '
      'transportConnected=${protocol.isConnected}',
    );

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
          wantAck: true,
        ),
      );

      // Show snackbar that message is queued
      if (mounted) {
        showInfoSnackBar(context, context.l10n.messagingMessageQueuedOffline);
      }
      return;
    }

    AppLogging.messages(
      '📤 RETRY_DISPATCH messageId=${message.id} '
      'isBroadcast=${message.isBroadcast} '
      'protocolReadiness=${protocol.readiness} '
      'retryCount=${message.retryCount}',
    );

    try {
      int packetId;

      if (message.isBroadcast) {
        packetId = await protocol.sendMessage(
          text: message.text,
          to: 0xFFFFFFFF,
          channel: message.channel ?? 0,
          wantAck: true,
          messageId: message.id,
          source: message.source, // Preserve original source
        );
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

      AppLogging.messages(
        '📤 RETRY_OK messageId=${message.id} packetId=$packetId',
      );
      messagesNotifier.updateMessage(
        message.id,
        message.copyWith(
          status: MessageStatus.sent,
          errorMessage: null,
          routingError: null,
          packetId: packetId,
          sentAt: message.sentAt ?? DateTime.now(),
          lastAttemptAt: DateTime.now(),
          retryCount: message.retryCount + 1,
        ),
      );
    } catch (e, st) {
      AppLogging.messages(
        '📤 RETRY_FAIL messageId=${message.id} error=$e '
        'protocolReadiness=${protocol.readiness} '
        'configurationComplete=${protocol.configurationComplete} '
        'transportConnected=${protocol.isConnected}',
      );
      AppLogging.messages('📤 RETRY_FAIL_STACK $st');

      // Check mounted after await before updating state
      if (!mounted) return;

      // Retry is silent on readiness-gate failures — the user already saw
      // the snackbar on the original Send. Mark the bubble failed with the
      // localised readiness message; the readiness->ready auto-resend
      // listener will pick it up and dispatch again as soon as the radio is
      // ready. For non-readiness errors, surface the generic snackbar.
      final isReadinessBlocked = isTxBlockedNotReadyError(e);
      if (!isReadinessBlocked) {
        maybeShowTxBlockedSnackBar(context, e);
      }
      AppLogging.messages(
        '📤 RETRY_FAIL_KIND messageId=${message.id} '
        'readinessBlocked=$isReadinessBlocked',
      );
      messagesNotifier.updateMessage(
        message.id,
        message.copyWith(
          status: MessageStatus.failed,
          errorMessage: isReadinessBlocked
              ? context.l10n.txBlockedNotReady
              : e.toString(),
        ),
      );
    }
  }

  void _showPkiFixSheet(Message message) {
    _showKeyRefreshSheet(
      targetNodeNum: message.to,
      warningText: message.routingError?.fixSuggestion,
      retryMessage: message,
    );
  }

  /// Encryption-key recovery sheet: Request User Info, optional message
  /// retry, and the node-database reset escape hatch. Reached from a
  /// failed PKI message ([_showPkiFixSheet]) and from the DM thread's
  /// key-mismatch banner (no message to retry there).
  void _showKeyRefreshSheet({
    required int targetNodeNum,
    String? warningText,
    Message? retryMessage,
  }) {
    final nodes = ref.read(nodesProvider);
    final targetNode = nodes[targetNodeNum];
    final targetName =
        targetNode?.displayName ?? context.l10n.messagingUnknownNode;

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
            title: context.l10n.messagingEncryptionKeyIssueTitle,
            // The "failed" phrasing is only true when arriving from a
            // failed message; the banner path states the key change
            // without asserting a delivery failure.
            subtitle: retryMessage != null
                ? context.l10n.messagingEncryptionKeyIssueSubtitle(targetName)
                : context.l10n.messagingKeyMismatchSheetSubtitle(targetName),
          ),
          SizedBox(height: AppTheme.spacing16),
          StatusBanner.warning(
            title: warningText ?? context.l10n.messagingEncryptionKeyWarning,
          ),
          const SizedBox(height: AppTheme.spacing20),
          // Request User Info button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(parentContext);
                try {
                  await protocol.requestNodeInfo(targetNodeNum);
                  if (mounted) {
                    showGlobalInfoSnackBar(
                      context.l10n.messagingRequestUserInfoSuccess(targetName),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    showGlobalErrorSnackBar(
                      context.l10n.messagingRequestUserInfoFailed(e.toString()),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 20),
              label: Text(
                context.l10n.messagingRequestUserInfo,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (retryMessage != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            // Retry message button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(parentContext);
                  if (mounted) {
                    _retryMessage(retryMessage);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textSecondary,
                  side: BorderSide(color: context.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                icon: const Icon(Icons.send, size: 20),
                label: Text(
                  context.l10n.messagingRetryMessage,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing8),
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
              context.l10n.messagingAdvancedResetNodeDatabase,
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(Message message) async {
    // Capture notifier before async gap
    final messagesNotifier = ref.read(messagesProvider.notifier);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.messagingDeleteMessageTitle,
      message: context.l10n.messagingDeleteMessageConfirmation,
      confirmLabel: context.l10n.commonDelete,
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    messagesNotifier.deleteMessage(message.id);
    showSuccessSnackBar(context, context.l10n.messagingMessageDeleted);
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
      // Use the live-resolved title so a sheet opened right after a
      // channel rename gets the fresh name, not the stale widget.title
      // captured at ChatScreen construction.
      displayTitle: _resolveAppBarTitle(context, channels),
    );
  }

  /// Resolve the live AppBar title for this conversation. For channel
  /// conversations, looks up the channel by index in [channels] and
  /// applies the same empty-name fallback the rest of the app uses
  /// (see channel_selector_sheet.dart): empty name on channel 0 -> the
  /// localized "Primary" label; empty name on any other channel ->
  /// "Channel N". For DMs, falls through to [widget.title] (the
  /// contact name captured at construction; no equivalent live
  /// provider rename exists today).
  String _resolveAppBarTitle(
    BuildContext context,
    List<ChannelConfig> channels,
  ) {
    if (widget.type != ConversationType.channel ||
        widget.channelIndex == null) {
      return widget.title;
    }
    final channel = channels.firstWhereOrNull(
      (c) => c.index == widget.channelIndex,
    );
    if (channel == null) return widget.title;
    if (channel.name.isNotEmpty) return channel.name;
    return channel.index == 0
        ? context.l10n.channelsPrimaryChannelName
        : context.l10n.channelsDefaultChannelName(channel.index);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    // Read (not watch) nodes/channels/offlineQueue: re-reading them on every
    // messagesProvider-driven rebuild gives fresh values in busy channels
    // without adding independent rebuild triggers on every node tick.
    final nodes = ref.read(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final channels = ref.read(channelsProvider);

    if (AppLogging.messagesLoggingEnabled) {
      AppLogging.messages(
        '📨 ConversationScreen.build: totalMessages=${messages.length}, '
        'myNodeNum=$myNodeNum, type=${widget.type}, '
        'channelIndex=${widget.channelIndex}, nodeNum=${widget.nodeNum}',
      );
    }

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
    final offlineQueue = ref.read(offlineQueueProvider);
    final queuedMessageIds = offlineQueue.queue.map((m) => m.id).toSet();

    // Filter visible messages for this conversation. These act as the fallback
    // while the DB-backed shaped timeline loads, and remain the source for
    // conversation-level debug logging.
    List<Message> fallbackMessages;
    if (widget.type == ConversationType.channel) {
      fallbackMessages = messages
          .where(
            (m) =>
                m.channel == widget.channelIndex &&
                m.isBroadcast &&
                !m.isCanonicalTapback,
          )
          .toList();
    } else {
      fallbackMessages = messages
          .where(
            (m) =>
                m.isDirect &&
                (m.from == widget.nodeNum || m.to == widget.nodeNum) &&
                !m.isCanonicalTapback,
          )
          .toList();
    }

    if (AppLogging.messagesLoggingEnabled) {
      AppLogging.messages(
        widget.type == ConversationType.channel
            ? '📨 Channel filter: channel=${widget.channelIndex}, '
                  'matched=${fallbackMessages.length}/${messages.length}'
            : '📨 DM filter: nodeNum=${widget.nodeNum}, '
                  'matched=${fallbackMessages.length}/${messages.length}',
      );
    }

    final timelineQuery = widget.type == ConversationType.channel
        ? ConversationTimelineQuery.channel(
            channelIndex: widget.channelIndex ?? 0,
          )
        : ConversationTimelineQuery.direct(
            peerNodeNum: widget.nodeNum,
            myNodeNum: myNodeNum,
          );
    _timelineController = ref.read(
      conversationTimelineControllerProvider.notifier,
    );
    if (_activeTimelineQuery != timelineQuery) {
      _resetTimelineState(timelineQuery);
      _scheduleTimelineInitialization(timelineQuery);
    }

    final timelineAsync = ref.watch(
      conversationTimelineStateProvider(timelineQuery),
    );
    if (timelineAsync == null) {
      _scheduleTimelineInitialization(timelineQuery);
    }

    final timelineState = timelineAsync?.asData?.value;
    final isTimelineLoading = timelineAsync == null || timelineAsync.isLoading;
    final rowSelection = selectConversationDisplayRows(
      fallbackMessages: fallbackMessages,
      timelineState: timelineState,
    );
    if (rowSelection.usedFallbackRows && timelineState != null) {
      AppLogging.messages(
        '📨 Using fallback rows: timelineRows=${timelineState.rows.length}, '
        'timelineMessages=${rowSelection.visibleTimelineMessageCount}, '
        'fallbackMessages=${fallbackMessages.length}',
      );
    }

    final unfilteredRows = rowSelection.rows;

    var filteredRows = [...unfilteredRows];

    // Mark any new unread messages as read while this chat is open.
    // _markAsRead() is only called once in initState, so messages arriving
    // after that are never marked — causing a persistent badge.
    final hasUnreadInView = unfilteredRows
        .map((row) => row.message)
        .whereType<Message>()
        .any((m) => m.received && m.from != myNodeNum && !m.read);
    if (hasUnreadInView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markAsRead();
      });
    }

    // Apply search filter if searching
    if (_isSearching && _searchQuery.isNotEmpty) {
      filteredRows = filteredRows
          .where(
            (row) =>
                row.message != null &&
                row.message!.text.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }

    // Capture whether the user was parked at the bottom on the PREVIOUS frame
    // before swapping in the new rows. _isNearLatest reads the live item
    // positions, which still reflect the prior layout — testing it after the
    // swap would check the newly-appended index (not yet laid out) and always
    // return false.
    final wasParkedAtLatest =
        _hasAppliedInitialRestore && _isNearLatest(_currentDisplayRows);

    _currentDisplayRows = filteredRows;

    if (timelineState != null &&
        !_isSearching &&
        !_hasAppliedInitialRestore &&
        !_isApplyingInitialRestore) {
      _scheduleInitialRestore(timelineQuery);
    }

    final visibleMessages = filteredRows
        .map((row) => row.message)
        .whereType<Message>()
        .toList();

    // Auto-scroll to the newest message when one arrives while the user is
    // already parked at the bottom. Honour the user's scroll position — if
    // they've scrolled up to read history, the Jump-to-Latest pill handles it.
    final latestMessage = visibleMessages.isNotEmpty
        ? visibleMessages.last
        : null;
    final latestMessageId = latestMessage?.id;
    final isNewInbound =
        latestMessage != null &&
        latestMessageId != _lastSeenLatestMessageId &&
        _lastSeenLatestMessageId != null &&
        latestMessage.received &&
        latestMessage.from != myNodeNum;
    if (isNewInbound &&
        wasParkedAtLatest &&
        !(_isSearching && _searchQuery.isNotEmpty)) {
      final query = _activeTimelineQuery;
      if (query != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_scrollToLatest(query, animate: true));
        });
      }
    }
    _lastSeenLatestMessageId = latestMessageId;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            await _persistReadingPositionNow();
          }
        },
        child: GlassScaffold.body(
          hasScrollBody: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.textPrimary),
            onPressed: () {
              _dismissKeyboard();
              if (_isSearching) {
                _toggleSearch();
                return;
              }
              // Pop synchronously. The PopScope above this scaffold
              // already calls _persistReadingPositionNow() after the
              // pop completes — awaiting before popping risked the
              // tap appearing dead if the storage write was slow or
              // wedged. Every other caller of _persistReadingPositionNow
              // in this file uses `unawaited()`; the back button now
              // matches that pattern.
              Navigator.of(context).pop();
            },
          ),
          titleWidget: GestureDetector(
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
                  // Scoped Consumer for the same reason as the title below:
                  // the outer build is hot-path on every messagesProvider
                  // tick, so only this avatar rebuilds when the peer node
                  // changes. The full 4-char shortName comes from the live
                  // node; widget.title is the long name and is only a
                  // fallback for peers not (yet) in the node DB.
                  Consumer(
                    builder: (context, ref, _) {
                      final peer = ref.watch(
                        nodesProvider.select((nodes) => nodes[widget.nodeNum]),
                      );
                      return NodeAvatar(
                        text:
                            peer?.avatarName ??
                            safeTruncate(sanitizeExternalText(widget.title), 4),
                        color: widget.avatarColor != null
                            ? Color(widget.avatarColor!)
                            : AppTheme.graphPurple,
                        size: 36,
                      );
                    },
                  ),
                SizedBox(width: AppTheme.spacing12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // For channels, the title in the AppBar must
                      // reflect rename edits live. Wrapping just the
                      // AutoScrollText in a Consumer keeps the existing
                      // `ref.read(channelsProvider)` discipline in the
                      // outer build (which is hot-path on every
                      // messagesProvider tick) and only rebuilds this
                      // one widget when channelsProvider changes. DMs
                      // fall through to widget.title since there is no
                      // equivalent live-rename source for contact
                      // names today.
                      Consumer(
                        builder: (context, ref, _) {
                          final liveTitle = _resolveAppBarTitle(
                            context,
                            ref.watch(channelsProvider),
                          );
                          return AutoScrollText(
                            liveTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          );
                        },
                      ),
                      Text(
                        widget.type == ConversationType.channel
                            ? context.l10n.messagingChannelSubtitle
                            : context.l10n.messagingDirectMessageSubtitle,
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
              tooltip: _isSearching
                  ? context.l10n.messagingCloseSearch
                  : context.l10n.messagingSearchMessages,
              onPressed: _toggleSearch,
            ),
            if (widget.type == ConversationType.channel)
              IconButton(
                icon: Icon(Icons.settings, color: context.textPrimary),
                tooltip: context.l10n.messagingChannelSettings,
                onPressed: () => _showChannelSettings(context, ref),
              ),
          ],
          body: Column(
            children: [
              // Search bar (same design as Nodes screen)
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    8,
                    16,
                    16,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: TextField(
                      maxLength: 100,
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: context.l10n.messagingFindMessageHint,
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
                        counterText: '',
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        context.l10n.messagingSearchResultsCount(
                          visibleMessages.length,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              // Key-mismatch warning for DM threads. Wrapped in a Consumer
              // so only this banner rebuilds on node updates - the outer
              // build is hot-path on every messagesProvider tick.
              if (widget.type == ConversationType.directMessage &&
                  widget.nodeNum != null)
                Consumer(
                  builder: (context, ref, _) {
                    final peer = ref.watch(
                      nodesProvider.select((nodes) => nodes[widget.nodeNum]),
                    );
                    if (peer == null || !peer.keyMismatch) {
                      return const SizedBox.shrink();
                    }
                    return StatusBanner.warning(
                      title: context.l10n.messagingKeyMismatchBannerTitle,
                      subtitle: context.l10n.messagingKeyMismatchBannerBody,
                      icon: Icons.key_off,
                      margin: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        AppTheme.spacing8,
                        AppTheme.spacing16,
                        AppTheme.spacing8,
                      ),
                      onTap: () =>
                          _showKeyRefreshSheet(targetNodeNum: widget.nodeNum!),
                    );
                  },
                ),
              // Messages
              Expanded(
                child: filteredRows.isEmpty
                    ? isTimelineLoading && fallbackMessages.isEmpty
                          ? const Center(child: LoadingIndicator())
                          : Center(
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
                                  SizedBox(height: AppTheme.spacing16),
                                  Text(
                                    _isSearching
                                        ? context
                                              .l10n
                                              .messagingNoMessagesMatchSearch
                                        : widget.type ==
                                              ConversationType.channel
                                        ? context
                                              .l10n
                                              .messagingNoMessagesInChannel
                                        : context
                                              .l10n
                                              .messagingStartConversation,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                    : Stack(
                        children: [
                          Builder(
                            builder: (context) {
                              // "New messages" divider boundary. Suppressed during
                              // search so the helper never anchors against a
                              // filtered window. Index returned by the helper
                              // points at the row the divider should sit ABOVE.
                              // Wrapping in the same slot (instead of adding a
                              // separate list item) preserves index parity with
                              // every scroll/restore helper that reads from
                              // `_currentDisplayRows[position.index]`.
                              final dividerInsertIndex = _isSearching
                                  ? -1
                                  : messagingUnreadDividerInsertIndex(
                                      messageCount: filteredRows.length,
                                      unreadCount: _initialUnreadCount,
                                    );
                              return ScrollablePositionedList.builder(
                                itemScrollController: _timelineScrollController,
                                itemPositionsListener: _itemPositionsListener,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                physics: const ClampingScrollPhysics(),
                                itemCount: filteredRows.length,
                                itemBuilder: (context, index) {
                                  final row = filteredRows[index];
                                  final showDividerAbove =
                                      dividerInsertIndex == index;

                                  if (row.isOrphanPlaceholder) {
                                    return KeyedSubtree(
                                      key: ValueKey(row.key),
                                      child: showDividerAbove
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const MessagingUnreadDivider(),
                                                _OrphanTapbackPlaceholder(
                                                  row: row,
                                                ),
                                              ],
                                            )
                                          : _OrphanTapbackPlaceholder(row: row),
                                    );
                                  }

                                  final message = row.message!;
                                  final isFromMe = message.from == myNodeNum;

                                  if (index == filteredRows.length - 1 &&
                                      AppLogging.messagesLoggingEnabled) {
                                    AppLogging.messages(
                                      '📨 Latest visible message: from=${message.from}, myNodeNum=$myNodeNum, isFromMe=$isFromMe, text="${message.text.substring(0, message.text.length.clamp(0, 20))}"',
                                    );
                                  }

                                  final senderNode = nodes[message.from];
                                  final senderName =
                                      senderNode?.displayName ??
                                      message.senderDisplayName;
                                  final senderShortName =
                                      senderNode?.shortName ??
                                      message.senderAvatarName;
                                  final avatarColor =
                                      senderNode?.avatarColor ??
                                      message.senderAvatarColor;

                                  final bubble = _MessageBubble(
                                    message: message,
                                    allMessages: visibleMessages,
                                    tapbacks: row.tapbacks,
                                    isFromMe: isFromMe,
                                    senderName: senderName,
                                    senderShortName: senderShortName,
                                    avatarColor: avatarColor,
                                    showSender:
                                        widget.type ==
                                            ConversationType.channel &&
                                        !isFromMe,
                                    isEncrypted: isEncrypted,
                                    isDm:
                                        widget.type ==
                                        ConversationType.directMessage,
                                    isQueued: queuedMessageIds.contains(
                                      message.id,
                                    ),
                                    isHighlighted:
                                        _highlightedMessageId == message.id,
                                    showTechInfo: _expandedTechInfoIds.contains(
                                      message.id,
                                    ),
                                    onToggleTechInfo: () {
                                      ref.haptics.trigger(HapticType.light);
                                      setState(() {
                                        if (_expandedTechInfoIds.contains(
                                          message.id,
                                        )) {
                                          _expandedTechInfoIds.remove(
                                            message.id,
                                          );
                                        } else {
                                          _expandedTechInfoIds.add(message.id);
                                        }
                                      });
                                    },
                                    channelIndex:
                                        widget.type == ConversationType.channel
                                        ? widget.channelIndex
                                        : null,
                                    onReply: () => _setReplyTo(message),
                                    onRetry: message.isFailed
                                        ? () => _retryMessage(message)
                                        : null,
                                    onResend: isFromMe && message.canResend
                                        ? () => ref
                                              .read(dmRetryCoordinatorProvider)
                                              .scheduleResend(message)
                                        : null,
                                    onAutoRetry:
                                        isFromMe && message.canEnableAutoRetry
                                        ? () => ref
                                              .read(dmRetryCoordinatorProvider)
                                              .enableAutoRetry(message.id)
                                        : null,
                                    onStopRetry:
                                        isFromMe && message.canStopAutoRetry
                                        ? () => ref
                                              .read(dmRetryCoordinatorProvider)
                                              .disableAutoRetry(message.id)
                                        : null,
                                    onPkiFix:
                                        message.routingError?.isPkiRelated ==
                                            true
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
                                    onQuoteTap: message.replyId != null
                                        ? () {
                                            ref.haptics.trigger(
                                              HapticType.light,
                                            );
                                            unawaited(
                                              _scrollToQuotedMessage(
                                                message.replyId!,
                                              ),
                                            );
                                          }
                                        : null,
                                  );

                                  return KeyedSubtree(
                                    key: ValueKey(row.key),
                                    child: showDividerAbove
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const MessagingUnreadDivider(),
                                              bubble,
                                            ],
                                          )
                                        : bubble,
                                  );
                                },
                              );
                            },
                          ),
                          if (timelineState?.isLoadingOlder == true)
                            Positioned(
                              top: AppTheme.spacing8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacing12,
                                    vertical: AppTheme.spacing6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.card.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius12,
                                    ),
                                    border: Border.all(color: context.border),
                                  ),
                                  child: const LoadingIndicator(size: 14),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: AppTheme.spacing12,
                            child: JumpToLatestPill(
                              visible: _showJumpToLatest,
                              onTap: _jumpToLatest,
                              label: context.l10n.messagingJumpToLatest,
                            ),
                          ),
                        ],
                      ),
              ),

              // Reply banner
              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    10,
                    8,
                    10,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
                    border: Border(
                      top: BorderSide(
                        color: context.border.withValues(alpha: 0.3),
                      ),
                      bottom: BorderSide(
                        color: context.border.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 18, color: context.accentColor),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.messagingReplyingTo(
                                _replyingTo!.senderDisplayName,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.accentColor,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              safeSubstring(_replyingTo!.text, 80),
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: context.textTertiary,
                        ),
                        onPressed: _clearReply,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),

              // Input
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border(
                    top: _replyingTo != null
                        ? BorderSide.none
                        : BorderSide(
                            color: context.border.withValues(alpha: 0.3),
                          ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Builder(
                    builder: (context) {
                      final composerPayloadSizer =
                          TextMessagePayloadSizer.standard(
                            replyId: _replyingTo?.packetId,
                          );

                      return ChatComposer(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        onSend: _sendMessage,
                        hintText: context.l10n.messagingMessageHint,
                        sendTooltip: context.l10n.messagingSendTooltip,
                        maxLength: composerPayloadSizer.maxUtf8Bytes,
                        budgetResolver: composerPayloadSizer.measure,
                        budgetLabelBuilder: (context, budget) =>
                            context.l10n.messagingComposerByteCounter(
                              budget.utf8Bytes,
                              budget.maxUtf8Bytes,
                            ),
                        leading: GestureDetector(
                          onTap: () => _showQuickResponses(),
                          // 48×48 mirrors the send button on the right
                          // of the composer so the leading and trailing
                          // affordances are visually balanced — same
                          // circle size, same icon size.
                          child: Container(
                            width: 48,
                            height: 48,
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
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrphanTapbackPlaceholder extends StatelessWidget {
  final ConversationTimelineRow row;

  const _OrphanTapbackPlaceholder({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.card.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppTheme.radius18),
              border: Border.all(color: context.border.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply, size: 14, color: context.textTertiary),
                const SizedBox(width: AppTheme.spacing6),
                Flexible(
                  child: Text(
                    context.l10n.messagingOriginalMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: context.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: TapbackDisplay(tapbacks: row.tapbacks),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final Message message;
  final List<Message> allMessages;
  final List<MessageTapback> tapbacks;
  final bool isFromMe;
  final String senderName;
  final String senderShortName;
  final int? avatarColor;
  final bool showSender;
  final bool isEncrypted;
  final bool isQueued;
  final int? channelIndex;
  final VoidCallback? onReply;
  final VoidCallback? onRetry;
  final VoidCallback? onResend;
  final VoidCallback? onAutoRetry;
  final VoidCallback? onStopRetry;
  final VoidCallback? onPkiFix;
  final VoidCallback? onDelete;
  final VoidCallback? onSenderTap;
  final VoidCallback? onQuoteTap;
  final bool isHighlighted;
  final bool isDm;
  final bool showTechInfo;
  final VoidCallback? onToggleTechInfo;

  const _MessageBubble({
    required this.message,
    required this.allMessages,
    required this.tapbacks,
    required this.isFromMe,
    required this.senderName,
    required this.senderShortName,
    this.avatarColor,
    this.showSender = true,
    this.isEncrypted = true,
    this.isQueued = false,
    this.isDm = false,
    this.channelIndex,
    this.onReply,
    this.onRetry,
    this.onResend,
    this.onAutoRetry,
    this.onStopRetry,
    this.onPkiFix,
    this.onDelete,
    this.onSenderTap,
    this.onQuoteTap,
    this.isHighlighted = false,
    this.showTechInfo = false,
    this.onToggleTechInfo,
  });

  Color _getAvatarColor() =>
      resolveNodeColor(nodeNum: message.from, avatarColor: avatarColor);

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
    return safeTruncate(sanitized, 4);
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
  String? _getSourceLabel(BuildContext context) {
    switch (message.source) {
      case MessageSource.automation:
        return context.l10n.messagingSourceAutomation;
      case MessageSource.siri:
        return context.l10n.messagingSourceShortcut;
      case MessageSource.reaction:
        return context.l10n.messagingSourceNotification;
      case MessageSource.tapback:
        return context.l10n.messagingSourceTapback;
      case MessageSource.manual:
      case MessageSource.unknown:
        return null;
    }
  }

  /// Get background color for source badge
  Color _getSourceColor() {
    switch (message.source) {
      case MessageSource.automation:
        return AppTheme.primaryPurple; // Purple
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
  Widget? _buildSourceBadge(BuildContext context) {
    final icon = _getSourceIcon();
    final label = _getSourceLabel(context);
    if (icon == null || label == null) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getSourceColor().withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: AppTheme.spacing4),
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

  /// Find the original message referenced by replyId
  Message? _findReplyMessage() {
    if (message.replyId == null) return null;
    for (final m in allMessages) {
      if (m.packetId == message.replyId) return m;
    }
    return null;
  }

  /// Build a reply quote block showing the original message
  Widget _buildReplyQuote(BuildContext context, {bool sentByMe = false}) {
    final replyMessage = _findReplyMessage();
    if (replyMessage == null && message.replyId == null) {
      return const SizedBox.shrink();
    }

    final replyText =
        replyMessage?.text ?? context.l10n.messagingOriginalMessage;
    final truncated = safeSubstring(replyText, 60);

    final quoteWidget = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: sentByMe
            ? Colors.white.withValues(alpha: 0.15)
            : context.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border(
          left: BorderSide(
            color: sentByMe
                ? Colors.white.withValues(alpha: 0.5)
                : context.accentColor.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.reply,
            size: 14,
            color: sentByMe
                ? Colors.white.withValues(alpha: 0.7)
                : context.textTertiary,
          ),
          const SizedBox(width: AppTheme.spacing6),
          Flexible(
            child: Text(
              truncated,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: sentByMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : context.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onQuoteTap != null) {
      return GestureDetector(onTap: onQuoteTap, child: quoteWidget);
    }
    return quoteWidget;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = AppTimeFormat.timeOnly(context);
    final isFailed = message.isFailed;
    final isUnconfirmed = message.isUnconfirmed;
    final isRetrying = message.isRetrying;
    final isPending = message.isPending;
    final sourceBadge = _buildSourceBadge(context);

    // Translation state for this message
    final translationState = ref.watch(messageTranslationProvider(message.id));

    // Restore cached translation on app restart for settled messages only.
    // Skip pending/sending messages — they haven't been translated yet and
    // the dedupe cache hit during build would cause state mutation that
    // interferes with message rendering.
    final isSettled = !isPending && !isRetrying && !isUnconfirmed;
    if (translationState == null &&
        message.text.trim().isNotEmpty &&
        isSettled) {
      ref
          .read(messageTranslationsProvider.notifier)
          .restoreFromCache(messageId: message.id, text: message.text);
    }

    // Determine if translate action should be available:
    // - has meaningful text content
    // - is not an emoji-only message (tapback)
    final isTranslatable = message.text.trim().isNotEmpty && !message.isEmoji;

    if (isFromMe) {
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      return AnimatedContainer(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 400),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? context.accentColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
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
                    onTap: onToggleTechInfo,
                    onLongPress: () => _showContextMenu(context, ref),
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
                            : (isUnconfirmed || isRetrying)
                            ? context.accentColor.withValues(alpha: 0.75)
                            : context.accentColor,
                        borderRadius: BorderRadius.circular(AppTheme.radius18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (message.replyId != null) ...[
                            _buildReplyQuote(context, sentByMe: true),
                            const SizedBox(height: AppTheme.spacing6),
                          ],
                          MessageBubbleBody(
                            text: message.text,
                            // Match inbound bubble size (15pt) so a
                            // back-and-forth thread reads with one
                            // consistent rhythm. Pre-existing 14/15
                            // split surfaced during D30 live smoke.
                            bodyStyle: chatBubbleBodyStyle(
                              baseFontSize: chatBubbleFontSize(
                                message.text,
                                baseFontSize: 14,
                              ),
                              color: Colors.white,
                            ),
                            fallbackStyle: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            linkStyle: const TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                          // Inline translation
                          if (isTranslatable)
                            _buildTranslationSection(
                              context,
                              translationState,
                              sentByMe: true,
                              ref: ref,
                            ),
                          const SizedBox(height: AppTheme.spacing2),
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
                                const SizedBox(width: AppTheme.spacing3),
                              ],
                              // Queued indicator
                              if (isQueued) ...[
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: AppTheme.spacing4),
                              ] else if (isPending) ...[
                                LoadingIndicator(size: 12),
                                const SizedBox(width: AppTheme.spacing4),
                              ],
                              Text(
                                timeFormat.format(message.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              if (!isPending && !isFailed && !isQueued) ...[
                                const SizedBox(width: AppTheme.spacing4),
                                _buildDeliveryGlyph(context),
                              ],
                            ],
                          ),
                          if (showTechInfo && isFromMe)
                            _buildInlineTechInfo(context, sentByMe: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: TapbackDisplay(tapbacks: tapbacks),
            ),
            if (isFailed) ...[
              const SizedBox(height: AppTheme.spacing4),
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
                        const SizedBox(width: AppTheme.spacing4),
                        Flexible(
                          child: Text(
                            message.errorMessage ??
                                context.l10n.messagingFailedToSend,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.errorRed,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(width: AppTheme.spacing8),
                          GestureDetector(
                            onTap: onRetry,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    size: 12,
                                    color: context.accentColor,
                                  ),
                                  SizedBox(width: AppTheme.spacing4),
                                  Text(
                                    context.l10n.commonRetry,
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
            if (isUnconfirmed || isRetrying) ...[
              const SizedBox(height: AppTheme.spacing4),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isRetrying)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: const Color(0xFFF59E0B),
                        ),
                      )
                    else
                      const Icon(
                        Icons.help_outline,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      isRetrying
                          ? context.l10n.messagingRetryProgress(
                              message.retryCount,
                              DmRetryConstants.maxAutoRetries,
                            )
                          : context.l10n.messagingStatusUnconfirmed,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    if (onResend != null) ...[
                      const SizedBox(width: AppTheme.spacing8),
                      GestureDetector(
                        onTap: onResend,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                          ),
                          child: Text(
                            context.l10n.messagingResend,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
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

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedContainer(
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 400),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? context.accentColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onToggleTechInfo,
                  onLongPress: () => _showContextMenu(context, ref),
                  child: Container(
                    margin: const EdgeInsets.only(right: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius18),
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
                          SizedBox(height: AppTheme.spacing2),
                        ],
                        if (message.replyId != null) ...[
                          _buildReplyQuote(context),
                          const SizedBox(height: AppTheme.spacing6),
                        ],
                        MessageBubbleBody(
                          text: message.text,
                          // Canonical chat-body size (14pt). Pre-D30 this
                          // was 15 on inbound and 14 on outbound; unified
                          // on 14 across MeshCore + SIP DM + messaging
                          // during the D30 polish pass.
                          bodyStyle: chatBubbleBodyStyle(
                            baseFontSize: chatBubbleFontSize(
                              message.text,
                              baseFontSize: 14,
                            ),
                            color: context.textPrimary,
                          ),
                          fallbackStyle: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: context.textTertiary,
                          ),
                        ),
                        // Inline translation
                        if (isTranslatable)
                          _buildTranslationSection(
                            context,
                            translationState,
                            sentByMe: false,
                            ref: ref,
                          ),
                        const SizedBox(height: AppTheme.spacing2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isEncrypted) ...[
                              Icon(
                                Icons.lock,
                                size: 10,
                                color: context.textTertiary,
                              ),
                              SizedBox(width: AppTheme.spacing3),
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
                        if (showTechInfo)
                          _buildInlineTechInfo(context, sentByMe: false),
                      ],
                    ),
                  ),
                ),
                if (message.hopCount != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppTheme.spacing2,
                      left: AppTheme.spacing4,
                    ),
                    child: HopCountChip(hopCount: message.hopCount!),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4),
                  child: TapbackDisplay(tapbacks: tapbacks),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a compact row of technical details (hops, SNR, RSSI, transport)
  /// shown inline below the message timestamp when the setting is enabled.
  // Delivery presentation for a settled outbound message (sent or delivered).
  // Centralises the sent → heard/delivered glyph so the bubble status row and
  // the tech-info panel always agree. Only meaningful once a message is past
  // pending/queued/failed; callers gate on that.
  ({IconData icon, Color color, double size, String label}) _deliveryStatus(
    BuildContext context,
  ) {
    final l10n = context.l10n;
    if (message.status != MessageStatus.delivered) {
      // Handed to the radio; no mesh acknowledgement yet.
      return (
        icon: Icons.done,
        color: Colors.white.withValues(alpha: 0.7),
        size: 14,
        label: l10n.messagingStatusSentToRadio,
      );
    }
    if (message.isBroadcast) {
      // Implicit mesh ack: a node repeated the broadcast.
      return (
        icon: Icons.done_all,
        color: Colors.white,
        size: 16,
        label: l10n.messagingStatusHeardByMesh,
      );
    }
    // Direct message delivered. realAck == false is a relay-only (implicit)
    // ack; anything else (explicit recipient ack, or legacy null rows) counts
    // as a recipient ack and gets the prominent success colour.
    if (message.realAck == false) {
      return (
        icon: Icons.done_all,
        color: Colors.white,
        size: 16,
        label: l10n.messagingStatusReceivedByRelay,
      );
    }
    return (
      icon: Icons.done_all,
      color: SemanticColors.success,
      size: 16,
      label: l10n.messagingStatusDelivered,
    );
  }

  // Tooltip-wrapped delivery glyph rendered inline in the outbound status row.
  Widget _buildDeliveryGlyph(BuildContext context) {
    final status = _deliveryStatus(context);
    return Tooltip(
      message: status.label,
      child: Icon(status.icon, size: status.size, color: status.color),
    );
  }

  Widget _buildInlineTechInfo(BuildContext context, {required bool sentByMe}) {
    final l10n = context.l10n;
    final hasRadioInfo =
        message.hopCount != null ||
        message.rxSnr != null ||
        message.rxRssi != null ||
        message.viaMqtt != null;

    final color = sentByMe
        ? Colors.white.withValues(alpha: 0.6)
        : context.textTertiary;
    final iconSize = AppTheme.spacing10;
    final textStyle = TextStyle(fontSize: AppTheme.spacing10, color: color);

    final nodeHex = message.from.toRadixString(16).padLeft(4, '0');

    // The bubble always carries a real wall-clock timestamp; flag only the
    // rare case where it looks unset (epoch/pre-2000) so a bad upstream
    // source can be traced. No message content is logged. This stays silent
    // for normal data, keeping the build path noise-free.
    if (message.timestamp.toLocal().year < 2000) {
      AppLogging.messages(
        'Tech info: packet ${message.packetId ?? 'n/a'} has implausible '
        'timestamp ${message.timestamp.toIso8601String()}; rendering as-is',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing2),
      child: Wrap(
        spacing: AppTheme.spacing8,
        runSpacing: AppTheme.spacing2,
        children: [
          // Always show: full local date + time (compact bubble keeps the
          // short time-only label; details surface the calendar date too).
          _TechInfoChip(
            icon: Icons.schedule,
            label: AppTimeFormat.relativeDateTime(
              context,
              message.timestamp,
              todayLabel: l10n.messagingTechInfoTimestampToday,
              yesterdayLabel: l10n.messagingTechInfoTimestampYesterday,
            ),
            iconSize: iconSize,
            color: color,
            textStyle: textStyle,
            explainTitle: l10n.messagingTechInfoExplainTimestampTitle,
            explainBody: l10n.messagingTechInfoExplainTimestampBody,
          ),
          // Outbound delivery status: human-readable text counterpart of the
          // bubble's check glyph (sent to radio / heard by mesh / delivered).
          if (sentByMe &&
              (message.status == MessageStatus.sent ||
                  message.status == MessageStatus.delivered))
            Builder(
              builder: (context) {
                final status = _deliveryStatus(context);
                return _TechInfoChip(
                  icon: status.icon,
                  label: status.label,
                  iconSize: iconSize,
                  color: color,
                  textStyle: textStyle,
                  explainTitle: l10n.messagingTechInfoExplainStatusTitle,
                  explainBody: l10n.messagingTechInfoExplainStatusBody,
                );
              },
            ),
          // Always show: from node ID
          _TechInfoChip(
            icon: Icons.person_outline,
            label: l10n.messagingTechInfoNodeId(nodeHex),
            iconSize: iconSize,
            color: color,
            textStyle: textStyle,
            explainTitle: l10n.messagingTechInfoExplainNodeIdTitle,
            explainBody: l10n.messagingTechInfoExplainNodeIdBody,
          ),
          // Always show: packet ID when available
          if (message.packetId != null)
            _TechInfoChip(
              icon: Icons.tag,
              label: l10n.messagingTechInfoPacketId(message.packetId!),
              iconSize: iconSize,
              color: color,
              textStyle: textStyle,
              explainTitle: l10n.messagingTechInfoExplainPacketIdTitle,
              explainBody: l10n.messagingTechInfoExplainPacketIdBody,
            ),
          if (message.hopCount != null)
            _TechInfoChip(
              icon: Icons.route,
              label: hopCountLabel(l10n, message.hopCount!),
              iconSize: iconSize,
              color: color,
              textStyle: textStyle,
              explainTitle: l10n.messagingTechInfoExplainHopsTitle,
              explainBody: l10n.messagingTechInfoExplainHopsBody,
            ),
          if (message.rxSnr != null)
            _TechInfoChip(
              icon: Icons.signal_cellular_alt,
              label: l10n.messagingTechInfoSnr(
                message.rxSnr!.toStringAsFixed(1),
              ),
              iconSize: iconSize,
              color: color,
              textStyle: textStyle,
              explainTitle: l10n.messagingTechInfoExplainSnrTitle,
              explainBody: l10n.messagingTechInfoExplainSnrBody,
            ),
          if (message.rxRssi != null)
            _TechInfoChip(
              icon: Icons.cell_tower,
              label: l10n.messagingTechInfoRssi(message.rxRssi!),
              iconSize: iconSize,
              color: color,
              textStyle: textStyle,
              explainTitle: l10n.messagingTechInfoExplainRssiTitle,
              explainBody: l10n.messagingTechInfoExplainRssiBody,
            ),
          if (message.viaMqtt != null)
            _TechInfoChip(
              icon: message.viaMqtt == true ? Icons.cloud : Icons.cell_tower,
              label: message.viaMqtt == true
                  ? l10n.messagingTechInfoMqtt
                  : l10n.messagingTechInfoRadio,
              iconSize: iconSize,
              color: color,
              textStyle: textStyle,
              explainTitle: l10n.messagingTechInfoExplainTransportTitle,
              explainBody: l10n.messagingTechInfoExplainTransportBody,
            ),
          // No radio metadata - show an explicit indicator, but only on
          // inbound bubbles. Outbound messages reach the radio over
          // BLE/USB, never over LoRa, so they can never carry receive
          // metadata; showing the indicator there reads as a fault. The
          // reference client likewise shows radio metadata only for
          // messages from other nodes.
          if (!sentByMe && !hasRadioInfo)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: iconSize, color: color),
                const SizedBox(width: AppTheme.spacing2),
                Text(l10n.messagingTechInfoNoRadioData, style: textStyle),
              ],
            ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    showMessageContextMenu(
      context,
      message: message,
      isFromMe: isFromMe,
      senderName: senderName,
      channelIndex: channelIndex,
      onReply: onReply,
      onDelete: onDelete,
      onResend: onResend,
      onAutoRetry: onAutoRetry,
      onStopRetry: onStopRetry,
      onTranslate: _isTranslatable(message, ref)
          ? () => _handleTranslate(context, ref)
          : null,
    );
  }

  bool _isTranslatable(Message msg, WidgetRef ref) {
    if (!AppFeatureFlags.isTranslationEnabled) return false;
    if (msg.text.trim().isEmpty || msg.isEmoji) return false;
    // Hide "Translate" if this message already has a successful translation
    final translationState = ref.read(messageTranslationProvider(msg.id));
    if (translationState?.result != null) return false;
    return true;
  }

  Future<void> _handleTranslate(BuildContext context, WidgetRef ref) async {
    // Await the subscription service directly — it's a FutureProvider that
    // resolves once RevenueCat initialization completes.  This is the source
    // of truth; purchaseStateProvider is just a reactive mirror that may not
    // have received _init()'s update yet.
    final service = await ref.read(subscriptionServiceProvider.future);
    if (!context.mounted) return;
    final hasFeature = service.currentState.hasFeature(
      PremiumFeature.translation,
    );
    if (!hasFeature) {
      checkPremiumOrShowUpsell(
        context: context,
        ref: ref,
        feature: PremiumFeature.translation,
      );
      return;
    }

    ref
        .read(messageTranslationsProvider.notifier)
        .translate(messageId: message.id, text: message.text, isDm: isDm);
  }

  Widget _buildTranslationSection(
    BuildContext context,
    MessageTranslationState? state, {
    required bool sentByMe,
    required WidgetRef ref,
  }) {
    if (state == null) return const SizedBox.shrink();

    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: AppTheme.spacing4),
        child: _TranslationShimmerLoading(
          label: context.l10n.translateLoading,
          sentByMe: sentByMe,
        ),
      );
    }

    if (state.error != null) {
      final String errorMessage;
      // Errors fixable via settings (not retryable)
      final bool isSettingsFixable;
      switch (state.error!.type) {
        case TranslationErrorType.offline:
          errorMessage = context.l10n.translateRequiresInternet;
          isSettingsFixable = false;
        case TranslationErrorType.rateLimited:
          errorMessage = context.l10n.translateRateLimited;
          isSettingsFixable = false;
        case TranslationErrorType.unsupportedLanguage:
          errorMessage = context.l10n.translateUnsupportedLanguage;
          isSettingsFixable = false;
        case TranslationErrorType.quotaExhausted:
          errorMessage = context.l10n.translateQuotaExhausted;
          isSettingsFixable = true;
        case TranslationErrorType.privacyBlocked:
          errorMessage = context.l10n.translatePrivacyBlocked;
          isSettingsFixable = true;
        case TranslationErrorType.providerDisabled:
          errorMessage = context.l10n.translateProviderDisabled;
          isSettingsFixable = true;
        case TranslationErrorType.byoKeyMissing:
          errorMessage = context.l10n.translateByoKeyMissing;
          isSettingsFixable = true;
        case TranslationErrorType.contentIneligible:
          errorMessage = context.l10n.translateContentIneligible;
          isSettingsFixable = false;
        case TranslationErrorType.authenticationRequired:
          errorMessage = context.l10n.translateAuthRequired;
          isSettingsFixable = true;
        case TranslationErrorType.emptyInput:
        case TranslationErrorType.apiError:
        case TranslationErrorType.configurationError:
          errorMessage = context.l10n.translateFailed;
          isSettingsFixable = false;
      }

      return Padding(
        padding: const EdgeInsets.only(top: AppTheme.spacing4),
        child: GestureDetector(
          onTap: isSettingsFixable
              ? () async {
                  HapticFeedback.selectionClick();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TranslationSettingsScreen(),
                    ),
                  );
                  if (!context.mounted) return;
                  ref
                      .read(messageTranslationsProvider.notifier)
                      .retry(
                        messageId: message.id,
                        text: message.text,
                        isDm: isDm,
                      );
                }
              : () => ref
                    .read(messageTranslationsProvider.notifier)
                    .retry(
                      messageId: message.id,
                      text: message.text,
                      isDm: isDm,
                    ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 12,
                color: sentByMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.errorRed,
              ),
              const SizedBox(width: AppTheme.spacing4),
              Flexible(
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: sentByMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.errorRed,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                isSettingsFixable
                    ? context.l10n.translationSettingsQuotaOpenSettings
                    : context.l10n.translateRetry,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sentByMe
                      ? Colors.white.withValues(alpha: 0.9)
                      : context.accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.result != null) {
      final result = state.result!;
      final sourceLabel = result.detectedSourceLanguage != null
          ? context.l10n.translateFromLanguage(result.detectedSourceLanguage!)
          : context.l10n.translateLabel;

      return Padding(
        padding: const EdgeInsets.only(top: AppTheme.spacing6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 1,
              color: sentByMe
                  ? Colors.white.withValues(alpha: 0.15)
                  : context.textTertiary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate,
                  size: 11,
                  color: sentByMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  sourceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: sentByMe
                        ? Colors.white.withValues(alpha: 0.6)
                        : context.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              result.translatedText,
              style: TextStyle(
                fontSize: 14,
                color: sentByMe
                    ? Colors.white.withValues(alpha: 0.85)
                    : context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing20, 0, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Icon(Icons.bolt, color: context.accentColor, size: 18),
                ),
                SizedBox(width: AppTheme.spacing12),
                Text(
                  context.l10n.messagingQuickResponses,
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
                    padding: const EdgeInsets.all(AppTheme.spacing32),
                    child: Text(
                      context.l10n.messagingNoQuickResponsesConfigured,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textSecondary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
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
                  SizedBox(width: AppTheme.spacing8),
                  Text(
                    context.l10n.messagingConfigureQuickResponses,
                    style: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing4),
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
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
          case 'week_view':
            if (!AppFeatureFlags.isMessageTimelineEnabled) {
              break;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessageTimelineScreen()),
            );
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
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.messagingAddChannel,
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
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.messagingScanQrCode,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }
        if (AppFeatureFlags.isMessageTimelineEnabled) {
          items.add(
            PopupMenuItem(
              value: 'week_view',
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_view_week,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.messagingWeekView,
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
                const SizedBox(width: AppTheme.spacing12),
                Text(
                  context.l10n.messagingHelp,
                  style: TextStyle(color: context.textPrimary),
                ),
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
                const SizedBox(width: AppTheme.spacing12),
                Text(
                  context.l10n.messagingSettings,
                  style: TextStyle(color: context.textPrimary),
                ),
              ],
            ),
          ),
        ]);
        return items;
      },
    );
  }
}

/// Shimmer loading indicator for inline translation, matching the screenshot
/// skeleton aesthetic.
class _TranslationShimmerLoading extends StatefulWidget {
  const _TranslationShimmerLoading({
    required this.label,
    required this.sentByMe,
  });

  final String label;
  final bool sentByMe;

  @override
  State<_TranslationShimmerLoading> createState() =>
      _TranslationShimmerLoadingState();
}

class _TranslationShimmerLoadingState extends State<_TranslationShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      final textColor = widget.sentByMe
          ? Colors.white.withValues(alpha: 0.6)
          : context.textTertiary;
      final iconColor = widget.sentByMe
          ? Colors.white.withValues(alpha: 0.5)
          : context.textTertiary.withValues(alpha: 0.7);
      final pillColor = widget.sentByMe
          ? Colors.white.withValues(alpha: 0.08)
          : context.textTertiary.withValues(alpha: 0.06);

      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing6,
          ),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate_rounded, size: 14, color: iconColor),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final textColor = widget.sentByMe
        ? Colors.white.withValues(alpha: 0.6)
        : context.textTertiary;
    final iconColor = widget.sentByMe
        ? Colors.white.withValues(alpha: 0.5)
        : context.textTertiary.withValues(alpha: 0.7);
    final pillColor = widget.sentByMe
        ? Colors.white.withValues(alpha: 0.08)
        : context.textTertiary.withValues(alpha: 0.06);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final shimmerOpacity = widget.sentByMe
            ? 0.06 + (_animation.value * 0.12)
            : 0.03 + (_animation.value * 0.08);
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: AppTheme.spacing4,
            ),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + (_animation.value * 3), -0.3),
                        end: Alignment(-0.5 + (_animation.value * 3), 0.3),
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: shimmerOpacity),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.translate, size: 13, color: iconColor),
                    const SizedBox(width: AppTheme.spacing6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A tappable inline chip displaying one technical detail about a message.
/// Tapping shows an explanation bottom sheet.
class _TechInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double iconSize;
  final Color color;
  final TextStyle textStyle;
  final String explainTitle;
  final String explainBody;

  const _TechInfoChip({
    required this.icon,
    required this.label,
    required this.iconSize,
    required this.color,
    required this.textStyle,
    required this.explainTitle,
    required this.explainBody,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showExplanation(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: AppTheme.spacing2),
          Text(label, style: textStyle),
        ],
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  explainTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.border.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: context.accentColor),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            explainBody,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
