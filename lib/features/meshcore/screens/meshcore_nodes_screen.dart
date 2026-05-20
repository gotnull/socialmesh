// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore Nodes screen.
//
// Standalone top-level tab (bottom-nav index 2) showing the full
// discovered-peer roster. Mirrors `NodesScreen` on the Meshtastic
// side: full node list with search, filter chips, and per-row
// quick-actions. Distinct from `MeshCoreMessagingScreen`, which is
// the conversations-only sub-tab inside the Messages container.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../models/meshcore_contact.dart';
import '../../../models/meshcore_contact_import_preview.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_contact_block_provider.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';
import '../widgets/meshcore_contact_card.dart';
import 'meshcore_chat_screen.dart';
import 'meshcore_contact_detail_screen.dart';
import 'meshcore_contact_import_sheet.dart';
import 'meshcore_qr_scanner_screen.dart';

class MeshCoreNodesScreen extends ConsumerStatefulWidget {
  const MeshCoreNodesScreen({super.key});

  @override
  ConsumerState<MeshCoreNodesScreen> createState() =>
      _MeshCoreNodesScreenState();
}

enum _MeshCoreNodeFilter { all, unread, chat, repeaters, other }

class _MeshCoreNodesScreenState extends ConsumerState<MeshCoreNodesScreen>
    with LifecycleSafeMixin<MeshCoreNodesScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  _MeshCoreNodeFilter _activeFilter = _MeshCoreNodeFilter.all;

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=nodes');
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

    final body = !isConnected
        ? _buildDisconnectedState()
        : contactsState.isLoading && allContacts.isEmpty
        ? _buildLoadingState()
        : contacts.isEmpty && allContacts.isEmpty
        ? _buildEmptyState(deviceName)
        : contacts.isEmpty
        ? _buildFilteredEmptyState()
        : _buildContactsList(contacts, allContacts, contactsState.isLoading);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold.body(
        hasScrollBody: true,
        resizeToAvoidBottomInset: false,
        leading: const MeshCoreHamburgerMenuButton(),
        title: context.l10n.nodesScreenTitle(allContacts.length),
        actions: [
          const MeshCoreDeviceStatusButton(),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'add_contact':
                  _showAddContactOptions();
                case 'add_from_clipboard':
                  _addContactFromClipboard();
                case 'broadcast_self':
                  _broadcastSelfContact();
                case 'discover':
                  _refreshContacts();
                case 'my_code':
                  _showMyContactCode();
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
                value: 'add_from_clipboard',
                child: ListTile(
                  leading: const Icon(Icons.content_paste_rounded),
                  title: Text(context.l10n.meshcoreContactsAddFromClipboard),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'broadcast_self',
                child: ListTile(
                  leading: const Icon(Icons.broadcast_on_personal_outlined),
                  title: Text(context.l10n.meshcoreBroadcastSelfContact),
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
            ],
          ),
        ],
        body: body,
      ),
    );
  }

  List<MeshCoreContact> _applyFilter(List<MeshCoreContact> contacts) {
    switch (_activeFilter) {
      case _MeshCoreNodeFilter.all:
        return contacts;
      case _MeshCoreNodeFilter.unread:
        return contacts.where((contact) => contact.unreadCount > 0).toList();
      case _MeshCoreNodeFilter.chat:
        return contacts.where((contact) => contact.type == 1).toList();
      case _MeshCoreNodeFilter.repeaters:
        return contacts.where((contact) => contact.type == 2).toList();
      case _MeshCoreNodeFilter.other:
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

  Widget _buildFilteredEmptyState() {
    final l10n = context.l10n;
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.filter_alt_off_rounded,
          Icons.filter_alt_outlined,
          Icons.people_outline_rounded,
        ],
        taglines: [l10n.meshcoreContactsFilteredEmptyTagline],
        titlePrefix: '',
        titleKeyword: l10n.meshcoreContactsFilteredEmptyTitle,
        titleSuffix: '',
        actionLabel: l10n.meshcoreContactsFilteredEmptyAction,
        actionIcon: Icons.clear_all_rounded,
        onAction: () => setState(() => _activeFilter = _MeshCoreNodeFilter.all),
        accentColor: AccentColors.cyan,
      ),
    );
  }

  Widget _buildEmptyState(String deviceName) {
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
                  isSelected: _activeFilter == _MeshCoreNodeFilter.all,
                  onTap: () =>
                      setState(() => _activeFilter = _MeshCoreNodeFilter.all),
                ),
                StatusFilterChip(
                  label: context.l10n.messagingFilterUnread,
                  count: unreadCount,
                  isSelected: _activeFilter == _MeshCoreNodeFilter.unread,
                  icon: Icons.mark_email_unread_outlined,
                  color: AccentColors.red,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreNodeFilter.unread,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.meshcoreFilterChatNodes,
                  count: chatCount,
                  isSelected: _activeFilter == _MeshCoreNodeFilter.chat,
                  icon: Icons.person,
                  color: AccentColors.blue,
                  onTap: () =>
                      setState(() => _activeFilter = _MeshCoreNodeFilter.chat),
                ),
                StatusFilterChip(
                  label: context.l10n.meshcoreFilterRepeaters,
                  count: repeaterCount,
                  isSelected: _activeFilter == _MeshCoreNodeFilter.repeaters,
                  icon: Icons.cell_tower_rounded,
                  color: AccentColors.green,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreNodeFilter.repeaters,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.meshcoreFilterOtherNodes,
                  count: otherCount,
                  isSelected: _activeFilter == _MeshCoreNodeFilter.other,
                  icon: Icons.device_unknown,
                  color: SemanticColors.disabled,
                  onTap: () =>
                      setState(() => _activeFilter = _MeshCoreNodeFilter.other),
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
            padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
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
        BottomSheetAction(
          icon: Icons.refresh_rounded,
          iconColor: context.accentColor,
          label: context.l10n.meshcoreResetPath,
          onTap: () {
            _resetContactPath(contact);
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

  Future<void> _broadcastSelfContact() async {
    final l10n = context.l10n;
    final notifier = ref.read(meshCoreContactsProvider.notifier);
    final ok = await notifier.broadcastSelfContact();
    if (!mounted) return;
    if (ok) {
      showSuccessSnackBar(context, l10n.meshcoreSelfContactBroadcasted);
    } else {
      showErrorSnackBar(context, l10n.meshcoreSelfContactBroadcastFailed);
    }
  }

  Future<void> _addContactFromClipboard() async {
    final l10n = context.l10n;
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = clip?.text ?? '';
    final MeshCoreContactImportPreview? preview = ref
        .read(meshCoreContactsProvider.notifier)
        .previewContactImport(text);
    if (!mounted) return;
    if (preview == null) {
      showErrorSnackBar(context, l10n.meshcoreContactImportParseFailed);
      return;
    }
    final result = await showMeshCoreContactImportSheet(
      context,
      preview: preview,
    );
    if (!mounted || result == null) return;
    if (result) {
      showSuccessSnackBar(context, l10n.meshcoreContactImported);
    } else {
      showErrorSnackBar(context, l10n.meshcoreContactImportFailed);
    }
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

    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .removeContact(contact.publicKeyHex);
    if (!mounted) return;
    if (ok) {
      showSuccessSnackBar(
        context,
        context.l10n.meshcoreContactRemoved(contact.name),
      );
    } else {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreContactRemoveFailed(contact.name),
      );
    }
  }

  Future<void> _resetContactPath(MeshCoreContact contact) async {
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .resetPath(contact.publicKeyHex);
    if (!mounted) return;
    if (ok) {
      showSuccessSnackBar(
        context,
        context.l10n.meshcoreResetPathSuccess(contact.name),
      );
    } else {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreResetPathFailed(contact.name),
      );
    }
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
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacing16,
                    ),
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
                  onPressed: () async {
                    final code = controller.text.trim();
                    final contact = parseContactCode(code);
                    if (contact == null) {
                      showErrorSnackBar(
                        context,
                        context.l10n.meshcoreInvalidContactCode,
                      );
                      return;
                    }
                    Navigator.pop(context);
                    final ok = await ref
                        .read(meshCoreContactsProvider.notifier)
                        .addContact(contact);
                    if (!mounted) return;
                    if (ok) {
                      showSuccessSnackBar(
                        context,
                        context.l10n.meshcoreContactAdded(contact.name),
                      );
                    } else {
                      showErrorSnackBar(
                        context,
                        context.l10n.meshcoreContactAddFailed(contact.name),
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
