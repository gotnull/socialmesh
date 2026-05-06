// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../models/meshcore_contact.dart';
import '../contact_l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_message_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';
import 'meshcore_chat_screen.dart';
import 'meshcore_qr_scanner_screen.dart';

/// MeshCore Contacts screen.
///
/// Displays discovered contacts via advertisements, allows adding contacts
/// via QR code, and shows contact status.
class MeshCoreContactsScreen extends ConsumerStatefulWidget {
  const MeshCoreContactsScreen({super.key});

  @override
  ConsumerState<MeshCoreContactsScreen> createState() =>
      _MeshCoreContactsScreenState();
}

enum _MeshCoreContactFilter { all, unread, chat, repeaters, other }

class _MeshCoreContactsScreenState extends ConsumerState<MeshCoreContactsScreen>
    with LifecycleSafeMixin<MeshCoreContactsScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  _MeshCoreContactFilter _activeFilter = _MeshCoreContactFilter.all;

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=contacts');
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
    final deviceName = linkStatus.deviceName ?? 'MeshCore';
    final contactsState = ref.watch(meshCoreContactsProvider);

    final allContacts = contactsState.contacts;
    var contacts = _applyFilter(allContacts);
    if (_searchQuery.isNotEmpty) {
      contacts = contacts.where((c) {
        final query = _searchQuery.toLowerCase();
        return c.name.toLowerCase().contains(query) ||
            c.publicKeyHex.toLowerCase().contains(query) ||
            c.typeLabel.toLowerCase().contains(query);
      }).toList();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold.body(
        hasScrollBody: true,
        resizeToAvoidBottomInset: false,
        leading: const MeshCoreHamburgerMenuButton(),
        title:
            '${context.l10n.meshcoreContactsTitle}${allContacts.isEmpty ? '' : ' (${allContacts.length})'}',
        actions: [
          const MeshCoreDeviceStatusButton(),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'add_contact':
                  _showAddContactOptions();
                case 'discover':
                  _refreshContacts();
                case 'my_code':
                  _showMyContactCode();
                case 'disconnect':
                  _disconnect();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add_contact',
                child: ListTile(
                  leading: const Icon(Icons.person_add_rounded),
                  title: Text(context.l10n.meshcoreAddContact),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'discover',
                child: ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text(context.l10n.meshcoreRefreshContacts),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'my_code',
                child: ListTile(
                  leading: const Icon(Icons.qr_code_rounded),
                  title: Text(context.l10n.meshcoreMyContactCode),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'disconnect',
                child: ListTile(
                  leading: const Icon(Icons.link_off_rounded),
                  title: Text(context.l10n.meshcoreDisconnect),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
        body: !isConnected
            ? _buildDisconnectedState()
            : contactsState.isLoading && allContacts.isEmpty
            ? _buildLoadingState()
            : contacts.isEmpty
            ? _buildEmptyState(deviceName)
            : _buildContactsList(
                contacts,
                allContacts,
                contactsState.isLoading,
              ),
      ),
    );
  }

  List<MeshCoreContact> _applyFilter(List<MeshCoreContact> contacts) {
    switch (_activeFilter) {
      case _MeshCoreContactFilter.all:
        return contacts;
      case _MeshCoreContactFilter.unread:
        return contacts.where((contact) => contact.unreadCount > 0).toList();
      case _MeshCoreContactFilter.chat:
        return contacts.where((contact) => contact.type == 1).toList();
      case _MeshCoreContactFilter.repeaters:
        return contacts.where((contact) => contact.type == 2).toList();
      case _MeshCoreContactFilter.other:
        return contacts
            .where((contact) => contact.type != 1 && contact.type != 2)
            .toList();
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
          Icons.people_outline_rounded,
          Icons.contact_page_outlined,
          Icons.cell_tower_rounded,
        ],
        taglines: [
          context.l10n.meshcoreDisconnectedContactsDescription,
          context.l10n.meshcoreContactsEmptyTagline1,
          context.l10n.meshcoreContactsEmptyTagline2,
        ],
        titlePrefix: '',
        titleKeyword: context.l10n.meshcoreDisconnectedTitle,
        titleSuffix: '',
      ),
    );
  }

  Widget _buildEmptyState(String deviceName) {
    // [deviceName] is no longer surfaced inline: the connected device is
    // already visible via the device-status button in the app bar; keeping
    // a separate "Connected to X" badge inside the empty state would be
    // duplicate UI and clash with the canonical AnimatedEmptyState shape.
    // The pull-to-refresh affordance on the list itself preserves the
    // refresh path without a secondary button.
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.people_outline_rounded,
          Icons.contact_page_outlined,
          Icons.person_search_rounded,
          Icons.qr_code_scanner_rounded,
          Icons.cell_tower_rounded,
          Icons.podcasts_rounded,
        ],
        taglines: [
          context.l10n.meshcoreContactsEmptyTagline1,
          context.l10n.meshcoreContactsEmptyTagline2,
          context.l10n.meshcoreContactsEmptyTagline3,
        ],
        titlePrefix: context.l10n.meshcoreContactsEmptyTitlePrefix,
        titleKeyword: context.l10n.meshcoreContactsEmptyTitleKeyword,
        titleSuffix: context.l10n.meshcoreContactsEmptyTitleSuffix,
        actionLabel: context.l10n.meshcoreAddContactButton,
        actionIcon: Icons.person_add_rounded,
        onAction: _showAddContactOptions,
        accentColor: AccentColors.cyan,
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
    final chatCount = allContacts.where((contact) => contact.type == 1).length;
    final repeaterCount = allContacts
        .where((contact) => contact.type == 2)
        .length;
    final otherCount = allContacts.length - chatCount - repeaterCount;
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
                chatCount,
                repeaterCount,
                otherCount,
              ]),
              filterChips: [
                StatusFilterChip(
                  label: context.l10n.messagingFilterAll,
                  count: allContacts.length,
                  isSelected: _activeFilter == _MeshCoreContactFilter.all,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreContactFilter.all,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.messagingFilterUnread,
                  count: unreadCount,
                  isSelected: _activeFilter == _MeshCoreContactFilter.unread,
                  icon: Icons.mark_email_unread_outlined,
                  color: AccentColors.red,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreContactFilter.unread,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.meshcoreFilterChatNodes,
                  count: chatCount,
                  isSelected: _activeFilter == _MeshCoreContactFilter.chat,
                  icon: Icons.person,
                  color: AccentColors.blue,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreContactFilter.chat,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.meshcoreFilterRepeaters,
                  count: repeaterCount,
                  isSelected: _activeFilter == _MeshCoreContactFilter.repeaters,
                  icon: Icons.cell_tower_rounded,
                  color: AccentColors.green,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreContactFilter.repeaters,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.meshcoreFilterOtherNodes,
                  count: otherCount,
                  isSelected: _activeFilter == _MeshCoreContactFilter.other,
                  icon: Icons.device_unknown,
                  color: SemanticColors.disabled,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreContactFilter.other,
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
                return _ContactCard(
                  contact: contact,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          MeshCoreChatScreen.contact(contact: contact),
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

  void _showAddContactOptions() {
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              context.l10n.meshcoreAddContact,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildOptionTile(
            icon: Icons.qr_code_scanner_rounded,
            title: context.l10n.meshcoreScanQrCode,
            subtitle: context.l10n.meshcoreScanContactQrSubtitle,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              _scanContactQr();
            },
          ),
          _buildOptionTile(
            icon: Icons.keyboard_rounded,
            title: context.l10n.meshcoreEnterCodeManually,
            subtitle: context.l10n.meshcoreTypeContactCode,
            onTap: () {
              Navigator.pop(context);
              _enterContactCode();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacing10),
        decoration: BoxDecoration(
          color: AccentColors.cyan.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Icon(icon, color: AccentColors.cyan),
      ),
      title: Text(title, style: TextStyle(color: context.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(color: context.textSecondary)),
      onTap: onTap,
    );
  }

  void _showMyContactCode() {
    final selfInfoState = ref.read(meshCoreSelfInfoProvider);
    final selfInfo = selfInfoState.selfInfo;

    if (selfInfo == null) {
      showInfoSnackBar(context, context.l10n.meshcoreSelfInfoNotAvailable);
      return;
    }

    final pubKeyHex = selfInfo.pubKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final contactCode = '$pubKeyHex:${selfInfo.nodeName}';

    QrShareSheet.show(
      context: context,
      title: selfInfo.nodeName,
      subtitle: context.l10n.meshcoreScanToAddMeSubtitle,
      qrData: contactCode,
      infoText: context.l10n.meshcoreShareContactCodeInfo,
    );
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
              ),
            );
          },
        ),
        BottomSheetAction(
          icon: Icons.share_rounded,
          label: context.l10n.meshcoreShareContact,
          onTap: () {
            final code = generateContactCode(contact);
            Clipboard.setData(ClipboardData(text: code));
            showSuccessSnackBar(
              context,
              context.l10n.meshcoreContactCodeCopied,
            );
          },
        ),
        BottomSheetAction(
          icon: Icons.delete_rounded,
          label: context.l10n.meshcoreRemoveContact,
          isDestructive: true,
          onTap: () {
            _confirmRemoveContact(contact);
          },
        ),
      ],
    );
  }

  Future<void> _confirmRemoveContact(MeshCoreContact contact) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.meshcoreRemoveContactTitle,
      message: context.l10n.meshcoreRemoveContactMessage(contact.name),
      confirmLabel: context.l10n.meshcoreRemove,
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    ref
        .read(meshCoreContactsProvider.notifier)
        .removeContact(contact.publicKeyHex);
    showSuccessSnackBar(
      context,
      context.l10n.meshcoreContactRemoved(contact.name),
    );
  }

  void _disconnect() async {
    final coordinator = ref.read(connectionCoordinatorProvider);
    await coordinator.disconnect();
  }

  void _scanContactQr() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const MeshCoreQrScannerScreen(mode: MeshCoreScanMode.contact),
      ),
    );
  }

  void _enterContactCode() {
    final controller = TextEditingController();

    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.meshcoreEnterContactCode,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            maxLength: 100,
            controller: controller,
            autofocus: true,
            maxLines: 3,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: context.l10n.meshcorePasteContactCodeHint,
              hintStyle: TextStyle(color: SemanticColors.muted),
              filled: true,
              fillColor: context.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.accentColor),
              ),
              prefixIcon: Icon(Icons.key_rounded, color: context.textSecondary),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              counterText: '',
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(context.l10n.meshcoreCancel),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: PrimaryGradientButton(
                  label: context.l10n.meshcoreAdd,
                  icon: Icons.person_add_rounded,
                  onPressed: () {
                    final code = controller.text.trim();
                    final contact = parseContactCode(code);
                    if (contact != null) {
                      Navigator.pop(context);
                      ref
                          .read(meshCoreContactsProvider.notifier)
                          .addContact(contact);
                      showSuccessSnackBar(
                        context,
                        context.l10n.meshcoreContactAdded(contact.name),
                      );
                    } else {
                      showErrorSnackBar(
                        context,
                        context.l10n.meshcoreInvalidContactCode,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

/// Card widget for displaying a single contact.
/// D19.C: now a `ConsumerWidget` so the tile reflects the live
/// last-message preview pulled from `meshCoreConversationsProvider`.
/// The unread badge keeps using `contact.unreadCount` (already
/// hydrated from SharedPreferences via the contacts notifier) but
/// falls back to the conversations provider's count when the
/// contacts notifier hasn't refreshed yet, so a freshly-arrived
/// inbound message bumps the badge immediately.
class _ContactCard extends ConsumerWidget {
  final MeshCoreContact contact;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ContactCard({
    required this.contact,
    required this.onTap,
    required this.onLongPress,
  });

  Color _getAvatarColor() {
    // Generate color from public key
    final colors = [
      AccentColors.cyan,
      AccentColors.purple,
      AccentColors.pink,
      AccentColors.green,
      AccentColors.orange,
      AccentColors.blue,
    ];
    final hash = contact.publicKeyHex.hashCode;
    return colors[hash.abs() % colors.length];
  }

  IconData _getTypeIcon() {
    switch (contact.type) {
      case 1: // Chat
        return Icons.person_rounded;
      case 2: // Repeater
        return Icons.cell_tower_rounded;
      case 3: // Room
        return Icons.meeting_room_rounded;
      case 4: // Sensor
        return Icons.sensors_rounded;
      default:
        return Icons.device_unknown_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarColor = _getAvatarColor();
    final conversationsState = ref.watch(meshCoreConversationsProvider);
    final conversation = conversationsState.conversations
        .where((c) => c.id == contact.publicKeyHex)
        .cast<MeshCoreConversation?>()
        .firstWhere((_) => true, orElse: () => null);
    final lastMessageText = conversation?.lastMessageText;
    // Prefer contact-store-hydrated count for stability; fall back to
    // the conversations notifier's live count for fresh inbound that
    // hasn't been re-read into the contacts state yet.
    final unreadCount = contact.unreadCount > 0
        ? contact.unreadCount
        : (conversation?.unreadCount ?? 0);

    return BouncyTap(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Center(
                  child: Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // D23: `displayName` falls through to the
                      // redacted pubkey fingerprint when the firmware
                      // contact entry has an empty name field. Only
                      // the rare empty-name + empty-pubkey case lands
                      // on the localized "Unknown" placeholder.
                      contact.displayName.isNotEmpty
                          ? contact.displayName
                          : context.l10n.meshcoreContactUnknownName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (lastMessageText != null &&
                        lastMessageText.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        lastMessageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? context.textPrimary
                              : context.textSecondary,
                          fontSize: 13,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing4),
                    Row(
                      children: [
                        Icon(
                          _getTypeIcon(),
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          contact.localizedTypeLabel(context.l10n),
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Icon(
                          Icons.route_rounded,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          contact.localizedPathLabel(context.l10n),
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        if (contact.snrDb != null) ...[
                          const SizedBox(width: AppTheme.spacing12),
                          _SnrBadge(snrDb: contact.snrDb!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Unread badge / chevron
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AccentColors.cyan,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// D28: Per-contact SNR badge.
///
/// Three signal bars colour-graded against the underlying dB and a
/// numeric label. Bars present so the badge reads as link-quality at a
/// glance; numeric label so the precise value is never hidden behind a
/// qualitative bucket. Hidden by the caller when SNR is unknown.
class _SnrBadge extends StatelessWidget {
  final double snrDb;
  const _SnrBadge({required this.snrDb});

  /// Three-step bar fill: 0 / 1 / 2 / 3 bars active.
  /// Thresholds picked to match LoRa SNR bands typical for MeshCore:
  /// `>=  0 dB` excellent (3), `>= -7 dB` good (2), `>= -12 dB` weak (1),
  /// below -12 dB very poor (0). Bars are visual hints; the numeric
  /// label is the source of truth.
  int get _activeBars {
    if (snrDb >= 0) return 3;
    if (snrDb >= -7) return 2;
    if (snrDb >= -12) return 1;
    return 0;
  }

  Color _accent(BuildContext context) {
    final bars = _activeBars;
    if (bars >= 3) return AccentColors.green;
    if (bars >= 2) return AccentColors.cyan;
    if (bars >= 1) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final active = _activeBars;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 3,
            height: 4 + i * 3.0,
            margin: EdgeInsets.only(
              right: i == 2 ? AppTheme.spacing6 : AppTheme.spacing2,
            ),
            decoration: BoxDecoration(
              color: i < active
                  ? accent
                  : context.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.spacing2 / 2),
            ),
          ),
        ],
        Text(
          context.l10n.meshcoreSnrLabel(snrDb.toStringAsFixed(1)),
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
