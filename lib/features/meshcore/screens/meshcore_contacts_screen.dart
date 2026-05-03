// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../models/meshcore_contact.dart';
import '../contact_l10n.dart';
import '../../../providers/app_providers.dart';
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

class _MeshCoreContactsScreenState extends ConsumerState<MeshCoreContactsScreen>
    with LifecycleSafeMixin<MeshCoreContactsScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

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

    // Filter contacts by search
    var contacts = contactsState.contacts;
    if (_searchQuery.isNotEmpty) {
      contacts = contacts.where((c) {
        final query = _searchQuery.toLowerCase();
        return c.name.toLowerCase().contains(query) ||
            c.publicKeyHex.toLowerCase().contains(query) ||
            c.typeLabel.toLowerCase().contains(query);
      }).toList();
    }

    return GlassScaffold.body(
      hasScrollBody: true,
      resizeToAvoidBottomInset: false,
      leading: const MeshCoreHamburgerMenuButton(),
      title:
          '${context.l10n.meshcoreContactsTitle}${contacts.isEmpty ? '' : ' (${contacts.length})'}',
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
              child: Row(
                children: [
                  Icon(
                    Icons.person_add_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.meshcoreAddContact,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'discover',
              child: Row(
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.meshcoreRefreshContacts,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'my_code',
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.meshcoreMyContactCode,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'disconnect',
              child: Row(
                children: [
                  Icon(
                    Icons.link_off_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.meshcoreDisconnect,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      body: !isConnected
          ? _buildDisconnectedState()
          : contactsState.isLoading && contacts.isEmpty
          ? _buildLoadingState()
          : contacts.isEmpty
          ? _buildEmptyState(deviceName)
          : _buildContactsList(contacts, contactsState.isLoading),
    );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off_rounded, size: 64, color: context.textTertiary),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.meshcoreDisconnectedTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.meshcoreDisconnectedContactsDescription,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String deviceName) {
    // [deviceName] is no longer surfaced inline — the connected device is
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

  Widget _buildContactsList(List<MeshCoreContact> contacts, bool isLoading) {
    return Column(
      children: [
        // Search bar
        SearchFilterHeader(
          searchController: _searchController,
          searchQuery: _searchQuery,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          hintText: context.l10n.meshcoreSearchContactsHint,
        ),
        // Contacts list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshContacts,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return _ContactCard(
                  contact: contact,
                  onTap: () => _showContactDetails(contact),
                  onLongPress: () => _showContactOptions(contact),
                );
              },
            ),
          ),
        ),
        if (isLoading)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
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
      ],
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

  void _showContactDetails(MeshCoreContact contact) {
    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          SectionTitle(title: context.l10n.meshcoreDeviceInfo),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.meshcoreChatInfoType,
                value: contact.localizedTypeLabel(context.l10n),
                icon: Icons.badge_outlined,
              ),
              InfoTableRow(
                label: context.l10n.meshcoreChatInfoPath,
                value: contact.localizedPathLabel(context.l10n),
                icon: Icons.alt_route_outlined,
              ),
              InfoTableRow(
                label: context.l10n.meshcorePublicKeySettingsLabel,
                value: contact.publicKeyHex,
                icon: Icons.key_outlined,
              ),
              if (contact.hasLocation)
                InfoTableRow(
                  label: context.l10n.meshcoreChatInfoLocation,
                  value:
                      '${contact.latitude?.toStringAsFixed(4)}, '
                      '${contact.longitude?.toStringAsFixed(4)}',
                  icon: Icons.place_outlined,
                ),
            ],
          ),
          SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MeshCoreChatScreen.contact(contact: contact),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(context.l10n.meshcoreMessageButton),
                ),
              ),
              SizedBox(width: AppTheme.spacing12),
              OutlinedButton.icon(
                onPressed: () {
                  final code = generateContactCode(contact);
                  Clipboard.setData(ClipboardData(text: code));
                  showSuccessSnackBar(
                    context,
                    context.l10n.meshcoreContactCodeCopied,
                  );
                },
                icon: const Icon(Icons.share_rounded),
                label: Text(context.l10n.meshcoreShare),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showContactOptions(MeshCoreContact contact) {
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_rounded, color: AccentColors.cyan),
            title: Text(
              context.l10n.meshcoreSendMessage,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      MeshCoreChatScreen.contact(contact: contact),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share_rounded, color: context.textSecondary),
            title: Text(
              context.l10n.meshcoreShareContact,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              final code = generateContactCode(contact);
              Clipboard.setData(ClipboardData(text: code));
              showSuccessSnackBar(
                context,
                context.l10n.meshcoreContactCodeCopied,
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_rounded, color: AppTheme.errorRed),
            title: Text(
              context.l10n.meshcoreRemoveContact,
              style: TextStyle(color: AppTheme.errorRed),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmRemoveContact(contact);
            },
          ),
        ],
      ),
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

    AppBottomSheet.show(
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
                child: FilledButton(
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
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(context.l10n.meshcoreAdd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a single contact.
class _ContactCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final avatarColor = _getAvatarColor();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
                      contact.name.isNotEmpty ? contact.name : 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
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
                      ],
                    ),
                  ],
                ),
              ),
              // Unread badge / chevron
              if (contact.unreadCount > 0)
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
                    '${contact.unreadCount}',
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
