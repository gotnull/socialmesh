// SPDX-License-Identifier: GPL-3.0-or-later
import '../../../core/safety/lifecycle_mixin.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../models/meshcore_contact.dart';
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
      leading: const MeshCoreHamburgerMenuButton(),
      title: 'Contacts${contacts.isEmpty ? '' : ' (${contacts.length})'}',
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
                  const SizedBox(width: 12),
                  Text(
                    'Add Contact',
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
                  const SizedBox(width: 12),
                  Text(
                    'Refresh Contacts',
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
                  const SizedBox(width: 12),
                  Text(
                    'My Contact Code',
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
                  const SizedBox(width: 12),
                  Text(
                    'Disconnect',
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading contacts...', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'MeshCore Disconnected',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a MeshCore device to view contacts',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String deviceName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GradientBorderContainer(
              borderRadius: 20,
              borderWidth: 1.5,
              accentColor: AccentColors.cyan,
              padding: const EdgeInsets.all(24),
              child: Icon(
                Icons.people_outline_rounded,
                size: 64,
                color: AccentColors.cyan.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Contacts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Contacts will appear here when discovered via advertisements.\n\n'
              'You can also add contacts manually using their contact code.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _showAddContactOptions,
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Add Contact'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AccentColors.cyan.withValues(alpha: 0.3),
                    foregroundColor: AccentColors.cyan,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _refreshContacts,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.8),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AccentColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AccentColors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AccentColors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connected to $deviceName',
                    style: TextStyle(
                      color: AccentColors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(List<MeshCoreContact> contacts, bool isLoading) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: Icon(Icons.search, color: context.textTertiary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
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
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Refreshing...',
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
              'Add Contact',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildOptionTile(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan QR Code',
            subtitle: "Scan a contact's QR code",
            onTap: () {
              Navigator.pop(context);
              _scanContactQr();
            },
          ),
          _buildOptionTile(
            icon: Icons.keyboard_rounded,
            title: 'Enter Code Manually',
            subtitle: 'Type a contact code',
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AccentColors.cyan.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AccentColors.cyan),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
      onTap: onTap,
    );
  }

  void _showMyContactCode() {
    final selfInfoState = ref.read(meshCoreSelfInfoProvider);
    final selfInfo = selfInfoState.selfInfo;

    if (selfInfo == null) {
      showInfoSnackBar(context, 'Self info not available');
      return;
    }

    final pubKeyHex = selfInfo.pubKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final contactCode = '$pubKeyHex:${selfInfo.nodeName}';

    QrShareSheet.show(
      context: context,
      title: selfInfo.nodeName,
      subtitle: 'Scan this code to add me as a contact',
      qrData: contactCode,
      infoText: 'Share your contact code so others can message you',
    );
  }

  void _showContactDetails(MeshCoreContact contact) {
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
          const SizedBox(height: 16),
          _buildDetailRow('Type', contact.typeLabel),
          _buildDetailRow('Path', contact.pathLabel),
          _buildDetailRow('Public Key', contact.shortPubKeyHex),
          if (contact.hasLocation)
            _buildDetailRow(
              'Location',
              '${contact.latitude?.toStringAsFixed(4)}, '
                  '${contact.longitude?.toStringAsFixed(4)}',
            ),
          const SizedBox(height: 16),
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
                  label: const Text('Message'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AccentColors.cyan.withValues(alpha: 0.3),
                    foregroundColor: AccentColors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final code = generateContactCode(contact);
                  Clipboard.setData(ClipboardData(text: code));
                  showSuccessSnackBar(context, 'Contact code copied');
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.8),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.end,
            ),
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
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_rounded, color: AccentColors.cyan),
            title: const Text(
              'Send Message',
              style: TextStyle(color: Colors.white),
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
            title: const Text(
              'Share Contact',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              final code = generateContactCode(contact);
              Clipboard.setData(ClipboardData(text: code));
              showSuccessSnackBar(context, 'Contact code copied');
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_rounded, color: AppTheme.errorRed),
            title: Text(
              'Remove Contact',
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

  void _confirmRemoveContact(MeshCoreContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: const Text(
          'Remove Contact?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove ${contact.name}?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(meshCoreContactsProvider.notifier)
                  .removeContact(contact.publicKeyHex);
              showSuccessSnackBar(context, '${contact.name} removed');
            },
            child: Text('Remove', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: const Text(
          'Enter Contact Code',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Paste contact code here...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final code = controller.text.trim();
              final contact = parseContactCode(code);
              if (contact != null) {
                Navigator.pop(ctx);
                ref.read(meshCoreContactsProvider.notifier).addContact(contact);
                showSuccessSnackBar(context, '${contact.name} added');
              } else {
                showErrorSnackBar(ctx, 'Invalid contact code');
              }
            },
            child: Text('Add', style: TextStyle(color: AccentColors.cyan)),
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getTypeIcon(),
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          contact.typeLabel,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.route_rounded,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          contact.pathLabel,
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
                    borderRadius: BorderRadius.circular(12),
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
