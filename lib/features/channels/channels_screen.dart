// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/channel.pbenum.dart' as channel_pbenum;
import '../messaging/messaging_screen.dart';
import '../navigation/main_shell.dart';
import 'channel_form_screen.dart';
import 'channel_wizard_screen.dart';

class ChannelsScreen extends ConsumerStatefulWidget {
  /// When true, shows only the body content without AppBar/Scaffold
  /// Used when embedded in tabs
  final bool embedded;

  const ChannelsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

enum ChannelFilter { all, primary, encrypted, position, mqtt }

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  ChannelFilter _activeFilter = ChannelFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  List<ChannelConfig> _applyFilter(List<ChannelConfig> channels) {
    switch (_activeFilter) {
      case ChannelFilter.all:
        return channels;
      case ChannelFilter.primary:
        return channels.where((c) => c.role == 'PRIMARY').toList();
      case ChannelFilter.encrypted:
        return channels.where((c) => c.hasSecureKey).toList();
      case ChannelFilter.position:
        return channels.where((c) => c.positionEnabled).toList();
      case ChannelFilter.mqtt:
        return channels.where((c) => c.uplink || c.downlink).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(channelsProvider);

    // Count channels by filter for badges
    final primaryCount = channels.where((c) => c.role == 'PRIMARY').length;
    final encryptedCount = channels.where((c) => c.hasSecureKey).length;
    final positionCount = channels.where((c) => c.positionEnabled).length;
    final mqttCount = channels.where((c) => c.uplink || c.downlink).length;

    // Apply filter first
    var filteredChannels = _applyFilter(channels);

    // Then filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredChannels = filteredChannels.where((channel) {
        return channel.name.toLowerCase().contains(query) ||
            channel.index.toString().contains(query);
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
                hintText: 'Search channels',
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
        // Filter chips row
        SizedBox(
          height: 44,
          child: EdgeFade.end(
            fadeSize: 32,
            fadeColor: context.background,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _ChannelFilterChip(
                  label: 'All',
                  count: channels.length,
                  isSelected: _activeFilter == ChannelFilter.all,
                  onTap: () =>
                      setState(() => _activeFilter = ChannelFilter.all),
                ),
                SizedBox(width: 8),
                _ChannelFilterChip(
                  label: 'Primary',
                  count: primaryCount,
                  isSelected: _activeFilter == ChannelFilter.primary,
                  color: AccentColors.blue,
                  icon: Icons.star,
                  onTap: () =>
                      setState(() => _activeFilter = ChannelFilter.primary),
                ),
                const SizedBox(width: 8),
                _ChannelFilterChip(
                  label: 'Encrypted',
                  count: encryptedCount,
                  isSelected: _activeFilter == ChannelFilter.encrypted,
                  color: AccentColors.green,
                  icon: Icons.lock,
                  onTap: () =>
                      setState(() => _activeFilter = ChannelFilter.encrypted),
                ),
                const SizedBox(width: 8),
                _ChannelFilterChip(
                  label: 'Position',
                  count: positionCount,
                  isSelected: _activeFilter == ChannelFilter.position,
                  color: AccentColors.orange,
                  icon: Icons.location_on,
                  onTap: () =>
                      setState(() => _activeFilter = ChannelFilter.position),
                ),
                const SizedBox(width: 8),
                _ChannelFilterChip(
                  label: 'MQTT',
                  count: mqttCount,
                  isSelected: _activeFilter == ChannelFilter.mqtt,
                  color: AccentColors.purple,
                  icon: Icons.cloud,
                  onTap: () =>
                      setState(() => _activeFilter = ChannelFilter.mqtt),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Divider
        Container(height: 1, color: context.border.withValues(alpha: 0.3)),
        // Channels list
        Expanded(
          child: filteredChannels.isEmpty
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
                          Icons.wifi_tethering,
                          size: 40,
                          color: context.textTertiary,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No channels match "$_searchQuery"'
                            : 'No channels configured',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          'Channels are still being loaded from device\nor use the icons above to add channels',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiary,
                          ),
                          textAlign: TextAlign.center,
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
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredChannels.length,
                  itemBuilder: (context, index) {
                    final channel = filteredChannels[index];
                    final animationsEnabled = ref.watch(
                      animationsEnabledProvider,
                    );
                    return Perspective3DSlide(
                      index: index,
                      direction: SlideDirection.left,
                      enabled: animationsEnabled,
                      child: _ChannelTile(
                        channel: channel,
                        animationsEnabled: animationsEnabled,
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
        topicId: 'channels_overview',
        stepKeys: const {},
        child: Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            leading: const HamburgerMenuButton(),
            centerTitle: true,
            title: Text(
              'Channels (${channels.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            actions: [
              const DeviceStatusButton(),
              AppBarOverflowMenu<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'add':
                      // Find next available channel index (1-7, 0 is Primary)
                      final usedIndices = channels.map((c) => c.index).toSet();
                      int nextIndex = 1;
                      for (int i = 1; i <= 7; i++) {
                        if (!usedIndices.contains(i)) {
                          nextIndex = i;
                          break;
                        }
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ChannelWizardScreen(channelIndex: nextIndex),
                        ),
                      );
                    case 'scan':
                      Navigator.of(context).pushNamed('/qr-scanner');
                    case 'settings':
                      Navigator.pushNamed(context, '/settings');
                    case 'help':
                      ref
                          .read(helpProvider.notifier)
                          .startTour('channels_overview');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'add',
                    child: ListTile(
                      leading: Icon(Icons.add),
                      title: Text('Add Channel'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'scan',
                    child: ListTile(
                      leading: Icon(Icons.qr_code_scanner),
                      title: Text('Scan QR Code'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'help',
                    child: ListTile(
                      leading: Icon(Icons.help_outline),
                      title: Text('Help'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: bodyContent,
        ),
      ),
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  final ChannelConfig channel;
  final bool animationsEnabled;

  const _ChannelTile({required this.channel, this.animationsEnabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrimary = channel.index == 0;
    final hasKey = channel.hasSecureKey;

    return BouncyTap(
      onTap: () => _openChannelChat(context),
      onLongPress: () => _showChannelOptions(context, ref),
      scaleFactor: animationsEnabled ? 0.98 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPrimary ? context.accentColor : context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${channel.index}',
                    style: TextStyle(
                      color: isPrimary ? Colors.white : context.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name.isEmpty
                          ? (isPrimary
                                ? 'Primary Channel'
                                : 'Channel ${channel.index}')
                          : channel.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          hasKey ? Icons.lock : Icons.lock_open,
                          size: 14,
                          color: hasKey
                              ? context.accentColor
                              : context.textTertiary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          hasKey ? 'Encrypted' : 'No encryption',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                        if (isPrimary) ...[
                          SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.accentColor,

                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _openChannelChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          type: ConversationType.channel,
          channelIndex: channel.index,
          title: channel.name.isEmpty
              ? (channel.index == 0
                    ? 'Primary Channel'
                    : 'Channel ${channel.index}')
              : channel.name,
        ),
      ),
    );
  }

  void _showChannelOptions(BuildContext context, WidgetRef ref) async {
    final actions = [
      BottomSheetAction(icon: Icons.edit, label: 'Edit Channel', value: 'edit'),
      BottomSheetAction(
        icon: Icons.key,
        label: 'View Encryption Key',
        value: 'key',
        enabled: channel.psk.isNotEmpty,
      ),
      BottomSheetAction(
        icon: Icons.qr_code,
        label: 'Show QR Code',
        value: 'qr',
        enabled: channel.psk.isNotEmpty,
      ),
      if (channel.index != 0)
        BottomSheetAction(
          icon: Icons.delete,
          label: 'Delete Channel',
          value: 'delete',
          isDestructive: true,
        ),
    ];

    final result = await AppBottomSheet.showActions<String>(
      context: context,
      actions: actions,
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChannelFormScreen(
              existingChannel: channel,
              channelIndex: channel.index,
            ),
          ),
        );
        break;
      case 'key':
        _showEncryptionKey(context);
        break;
      case 'qr':
        _showQrCode(context);
        break;
      case 'delete':
        _deleteChannel(context, ref);
        break;
    }
  }

  void _showEncryptionKey(BuildContext context) {
    final base64Key = base64Encode(channel.psk);
    final keyBits = channel.psk.length * 8;

    AppBottomSheet.show(
      context: context,
      child: _EncryptionKeyContent(
        base64Key: base64Key,
        keyBits: keyBits,
        keyBytes: channel.psk.length,
      ),
    );
  }

  void _showQrCode(BuildContext context) {
    // Build a proper protobuf Channel message for the QR code
    final channelSettings = channel_pb.ChannelSettings()
      ..name = channel.name
      ..psk = channel.psk;

    final pbChannel = channel_pb.Channel()
      ..index = channel.index
      ..settings = channelSettings
      ..role = channel.index == 0
          ? channel_pbenum.Channel_Role.PRIMARY
          : channel_pbenum.Channel_Role.SECONDARY;

    // Encode as base64 and URL-encode for the URL fragment
    final base64Data = base64Encode(pbChannel.writeToBuffer());
    final channelUrl = 'socialmesh://channel/$base64Data';

    final channelName = channel.name.isEmpty
        ? 'Channel ${channel.index}'
        : channel.name;

    QrShareSheet.show(
      context: context,
      title: channelName,
      subtitle: 'Scan to join this channel',
      qrData: channelUrl,
      infoText: 'Share this QR code to let others join your channel',
    );
  }

  void _deleteChannel(BuildContext context, WidgetRef ref) {
    // Check connection state before showing delete dialog
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, 'Cannot delete channel: Device not connected');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Channel'),
        content: Text('Delete channel "${channel.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Create disabled channel config
              final disabledChannel = ChannelConfig(
                index: channel.index,
                name: '',
                psk: [],
                uplink: false,
                downlink: false,
                role: 'DISABLED',
              );

              // Send to device first
              try {
                final protocol = ref.read(protocolServiceProvider);
                await protocol.setChannel(disabledChannel);

                // Update local state only after successful device sync
                ref
                    .read(channelsProvider.notifier)
                    .removeChannel(channel.index);

                // Don't show snackbar - the reconnecting overlay will handle UX
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(context, 'Failed to delete channel: $e');
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Stateful content for encryption key bottom sheet
class _EncryptionKeyContent extends StatefulWidget {
  final String base64Key;
  final int keyBits;
  final int keyBytes;

  const _EncryptionKeyContent({
    required this.base64Key,
    required this.keyBits,
    required this.keyBytes,
  });

  @override
  State<_EncryptionKeyContent> createState() => _EncryptionKeyContentState();
}

class _EncryptionKeyContentState extends State<_EncryptionKeyContent> {
  bool _showKey = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          icon: Icons.key,
          title: 'Encryption Key',
          subtitle: '${widget.keyBits}-bit · ${widget.keyBytes} bytes · Base64',
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
                  widget.base64Key,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.accentColor,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    height: 1.5,
                  ),
                )
              : Text(
                  '•' * 32,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textTertiary.withValues(alpha: 0.5),
                    fontFamily: AppTheme.fontFamily,
                    letterSpacing: 2,
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
                label: Text(
                  _showKey ? 'Hide' : 'Show',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showKey
                    ? () {
                        Clipboard.setData(
                          ClipboardData(text: widget.base64Key),
                        );
                        Navigator.pop(context);
                        showSuccessSnackBar(context, 'Key copied to clipboard');
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: context.background,
                  disabledForegroundColor: context.textTertiary.withValues(
                    alpha: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.copy, size: 20),
                label: const Text(
                  'Copy',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Filter chip widget for channels
class _ChannelFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  const _ChannelFilterChip({
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
            if (icon != null) ...[
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
