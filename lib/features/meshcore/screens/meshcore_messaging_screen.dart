// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold: always embedded inside MeshCoreMessagesContainerScreen's GlassScaffold
// lint-allow: haptic-feedback: outer GestureDetector dismisses the keyboard, not a user action

// MeshCore Messaging screen: the Contacts sub-tab inside the Messages
// container.
//
// Mirrors `MessagingScreen` on the Meshtastic side: shows the contacts
// the user has at least one persisted DM conversation with. Always
// renders embedded inside `MeshCoreMessagesContainerScreen`; the
// container owns the app bar + tab selector + DeviceStatusButton.
//
// Distinct from `MeshCoreNodesScreen`, which is the standalone
// top-level tab showing the full discovered-peer roster.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/routing/conversation_routes.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_contact_block_provider.dart';
import '../../../providers/meshcore_message_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../widgets/meshcore_contact_card.dart';
import 'meshcore_chat_screen.dart';
import 'meshcore_contact_detail_screen.dart';

class MeshCoreMessagingScreen extends ConsumerStatefulWidget {
  const MeshCoreMessagingScreen({super.key});

  @override
  ConsumerState<MeshCoreMessagingScreen> createState() =>
      _MeshCoreMessagingScreenState();
}

enum _MeshCoreConversationFilter { all, unread, favorites }

class _MeshCoreMessagingScreenState
    extends ConsumerState<MeshCoreMessagingScreen>
    with LifecycleSafeMixin<MeshCoreMessagingScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  _MeshCoreConversationFilter _activeFilter = _MeshCoreConversationFilter.all;

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=messaging');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final contactsState = ref.watch(meshCoreContactsProvider);
    final allContacts = _filterToContactsWithConversations(
      contactsState.contacts,
    );
    var contacts = _applyFilter(allContacts);
    if (_searchQuery.isNotEmpty) {
      contacts = contacts.where((c) {
        final query = _searchQuery.toLowerCase();
        return c.name.toLowerCase().contains(query) ||
            c.publicKeyHex.toLowerCase().contains(query) ||
            c.typeLabel.toLowerCase().contains(query);
      }).toList();
    }

    final body = !isConnected
        ? _buildDisconnectedState()
        : contactsState.isLoading && allContacts.isEmpty
        ? _buildLoadingState()
        : allContacts.isEmpty
        ? _buildEmptyState()
        : contacts.isEmpty
        ? _buildFilteredEmptyState()
        : _buildContactsList(contacts, allContacts, contactsState.isLoading);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(color: context.background, child: body),
    );
  }

  // Restrict to contacts whose pubkey is present in the conversations
  // provider's contact entries (channels excluded). The Messages -> Contacts
  // sub-tab only shows DM threads, not the full discovered roster.
  List<MeshCoreContact> _filterToContactsWithConversations(
    List<MeshCoreContact> contacts,
  ) {
    final convoIds = ref
        .watch(meshCoreConversationsProvider)
        .conversations
        .where((c) => !c.isChannel)
        .map((c) => c.id.toLowerCase())
        .toSet();
    if (convoIds.isEmpty) return const [];
    return contacts
        .where((c) => convoIds.contains(c.publicKeyHex.toLowerCase()))
        .toList();
  }

  List<MeshCoreContact> _applyFilter(List<MeshCoreContact> contacts) {
    switch (_activeFilter) {
      case _MeshCoreConversationFilter.all:
        return contacts;
      case _MeshCoreConversationFilter.unread:
        return contacts.where((contact) => contact.unreadCount > 0).toList();
      case _MeshCoreConversationFilter.favorites:
        return contacts.where((contact) => contact.isFavorite).toList();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.meshcoreLoadingContacts,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.link_off_rounded,
          Icons.router_outlined,
          Icons.bluetooth_disabled_rounded,
          Icons.chat_bubble_outline_rounded,
          Icons.message_outlined,
        ],
        taglines: [
          context.l10n.meshcoreDisconnectedContactsDescription,
          context.l10n.meshcoreMessagingEmptyHint,
        ],
        titlePrefix: '',
        titleKeyword: context.l10n.meshcoreDisconnectedTitle,
        titleSuffix: '',
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    final l10n = context.l10n;
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.filter_alt_off_rounded,
          Icons.filter_alt_outlined,
          Icons.chat_bubble_outline_rounded,
        ],
        taglines: [l10n.meshcoreContactsFilteredEmptyTagline],
        titlePrefix: '',
        titleKeyword: l10n.meshcoreContactsFilteredEmptyTitle,
        titleSuffix: '',
        actionLabel: l10n.meshcoreContactsFilteredEmptyAction,
        actionIcon: Icons.clear_all_rounded,
        onAction: () =>
            setState(() => _activeFilter = _MeshCoreConversationFilter.all),
        accentColor: context.accentColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.chat_bubble_outline_rounded,
          Icons.message_outlined,
          Icons.mark_chat_unread_outlined,
          Icons.forum_outlined,
          Icons.send_rounded,
        ],
        taglines: [
          context.l10n.meshcoreMessagingEmptyHint,
          context.l10n.meshcoreMessagingEmptyTaglineNodesTab,
        ],
        titlePrefix: context.l10n.meshcoreMessagingEmptyTitlePrefix,
        titleKeyword: context.l10n.meshcoreMessagingEmptyTitleKeyword,
        titleSuffix: context.l10n.meshcoreMessagingEmptyTitleSuffix,
        accentColor: context.accentColor,
      ),
    );
  }

  Widget _buildContactsList(
    List<MeshCoreContact> contacts,
    List<MeshCoreContact> allContacts,
    bool isLoading,
  ) {
    final unreadCount = allContacts
        .where((contact) => contact.unreadCount > 0)
        .length;
    final favoriteCount = allContacts
        .where((contact) => contact.isFavorite)
        .length;
    final textScaler = MediaQuery.textScalerOf(context);

    return RefreshIndicator(
      onRefresh: _refreshContacts,
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchFilterHeaderDelegate(
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              hintText: context.l10n.meshcoreSearchContactsHint,
              textScaler: textScaler,
              rebuildKey: Object.hashAll([
                _activeFilter,
                allContacts.length,
                unreadCount,
                favoriteCount,
              ]),
              filterChips: [
                StatusFilterChip(
                  label: context.l10n.messagingFilterAll,
                  count: allContacts.length,
                  isSelected: _activeFilter == _MeshCoreConversationFilter.all,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreConversationFilter.all,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.messagingFilterUnread,
                  count: unreadCount,
                  isSelected:
                      _activeFilter == _MeshCoreConversationFilter.unread,
                  icon: Icons.mark_email_unread_outlined,
                  color: AccentColors.red,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreConversationFilter.unread,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.messagingFilterFavorites,
                  count: favoriteCount,
                  isSelected:
                      _activeFilter == _MeshCoreConversationFilter.favorites,
                  icon: Icons.star_rounded,
                  color: AccentColors.yellow,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreConversationFilter.favorites,
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final contact = contacts[index];
                return MeshCoreContactCard(
                  contact: contact,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          MeshCoreChatScreen.contact(contact: contact),
                      settings: RouteSettings(
                        name: meshCoreContactRouteName(contact.publicKeyHex),
                      ),
                    ),
                  ),
                  onLongPress: () => _showContactOptions(contact),
                );
              }, childCount: contacts.length),
            ),
          ),
          if (isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: AppTheme.spacing16,
                      height: AppTheme.spacing16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.meshcoreRefreshing,
                      style: TextStyle(color: context.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshContacts() async {
    final notifier = ref.read(meshCoreContactsProvider.notifier);
    await notifier.refresh();
  }

  void _showContactOptions(MeshCoreContact contact) {
    AppBottomSheet.showActions<void>(
      context: context,
      header: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          contact.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.chat_rounded,
          iconColor: AccentColors.cyan,
          label: context.l10n.meshcoreSendMessage,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    MeshCoreChatScreen.contact(contact: contact),
                settings: RouteSettings(
                  name: meshCoreContactRouteName(contact.publicKeyHex),
                ),
              ),
            );
          },
        ),
        BottomSheetAction(
          icon: Icons.info_outline_rounded,
          iconColor: context.accentColor,
          label: context.l10n.meshcoreContactDetailViewDetails,
          onTap: () {
            openMeshCoreContactDetail(context, contact: contact);
          },
        ),
        BottomSheetAction(
          icon: contact.isFavorite
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          iconColor: AccentColors.yellow,
          label: contact.isFavorite
              ? context.l10n.meshcoreContactRemoveFavorite
              : context.l10n.meshcoreContactAddFavorite,
          onTap: () => _toggleFavorite(contact),
        ),
        BottomSheetAction(
          icon: _isBlocked(contact)
              ? Icons.notifications_active_rounded
              : Icons.notifications_off_outlined,
          iconColor: _isBlocked(contact)
              ? AccentColors.green
              : AccentColors.red,
          label: _isBlocked(contact)
              ? context.l10n.meshcoreContactUnblock
              : context.l10n.meshcoreContactBlock,
          onTap: () => _toggleBlock(contact),
        ),
        BottomSheetAction(
          icon: Icons.share_rounded,
          label: context.l10n.meshcoreShareContact,
          onTap: () => _shareContactUrl(contact),
        ),
      ],
    );
  }

  Future<void> _shareContactUrl(MeshCoreContact contact) async {
    final l10n = context.l10n;
    final notifier = ref.read(meshCoreContactsProvider.notifier);
    final url = await notifier.exportContactUrl(contact);
    if (!mounted) return;
    if (url == null) {
      showErrorSnackBar(context, l10n.meshcoreContactExportFailed);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showSuccessSnackBar(context, l10n.meshcoreContactUrlCopied);
  }

  bool _isBlocked(MeshCoreContact contact) {
    return ref
        .read(meshCoreContactBlockProvider.notifier)
        .isBlocked(contact.publicKeyHex);
  }

  Future<void> _toggleBlock(MeshCoreContact contact) async {
    final l10n = context.l10n;
    final notifier = ref.read(meshCoreContactBlockProvider.notifier);
    final wasBlocked = notifier.isBlocked(contact.publicKeyHex);
    if (wasBlocked) {
      await notifier.unblock(contact.publicKeyHex);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        l10n.meshcoreContactUnblockSuccess(contact.name),
      );
    } else {
      await notifier.block(contact.publicKeyHex);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        l10n.meshcoreContactBlockSuccess(contact.name),
      );
    }
  }

  Future<void> _toggleFavorite(MeshCoreContact contact) async {
    final wasFavorite = contact.isFavorite;
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .toggleContactFavorite(publicKeyHex: contact.publicKeyHex);
    if (!mounted) return;
    if (ok) {
      showSuccessSnackBar(
        context,
        wasFavorite
            ? context.l10n.meshcoreContactRemoveFavoriteSuccess(contact.name)
            : context.l10n.meshcoreContactAddFavoriteSuccess(contact.name),
      );
    } else {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreContactToggleFavoriteFailed(contact.name),
      );
    }
  }
}
