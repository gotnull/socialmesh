// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../models/meshcore_channel.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';
import 'meshcore_chat_screen.dart';
import 'meshcore_qr_scanner_screen.dart';

/// MeshCore Channels screen.
///
/// Displays MeshCore channels/rooms, allows creating and joining channels.
class MeshCoreChannelsScreen extends ConsumerStatefulWidget {
  const MeshCoreChannelsScreen({super.key});

  @override
  ConsumerState<MeshCoreChannelsScreen> createState() =>
      _MeshCoreChannelsScreenState();
}

class _MeshCoreChannelsScreenState
    extends ConsumerState<MeshCoreChannelsScreen> {
  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final deviceName = linkStatus.deviceName ?? 'MeshCore';
    final channelsState = ref.watch(meshCoreChannelsProvider);

    // Filter to only show configured channels (non-empty name or PSK)
    final channels = channelsState.channels
        .where((c) => c.name.isNotEmpty || !c.isDefaultPsk)
        .toList();

    return GlassScaffold.body(
      leading: const MeshCoreHamburgerMenuButton(),
      title: 'Channels${channels.isEmpty ? '' : ' (${channels.length})'}',
      actions: [
        const MeshCoreDeviceStatusButton(),
        AppBarOverflowMenu<String>(
          onSelected: (value) {
            switch (value) {
              case 'create':
                _showCreateChannelDialog();
              case 'join':
                _showJoinChannelDialog();
              case 'refresh':
                _refreshChannels();
              case 'disconnect':
                _disconnect();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'create',
              child: Row(
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create Channel',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'join',
              child: Row(
                children: [
                  Icon(
                    Icons.login_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Join Channel',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Refresh Channels',
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
          : channelsState.isLoading && channels.isEmpty
          ? _buildLoadingState()
          : channels.isEmpty
          ? _buildEmptyState(deviceName)
          : _buildChannelsList(channels, channelsState.isLoading),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading channels...', style: TextStyle(color: Colors.white70)),
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
              'Connect to a MeshCore device to view channels',
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
              accentColor: AccentColors.purple,
              padding: const EdgeInsets.all(24),
              child: Icon(
                Icons.forum_outlined,
                size: 64,
                color: AccentColors.purple.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Channels',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Channels are shared spaces for group communication.\n\n'
              'Create a new channel or join an existing one.',
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
                  onPressed: _showCreateChannelDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Channel'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AccentColors.purple.withValues(alpha: 0.3),
                    foregroundColor: AccentColors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showJoinChannelDialog,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Join'),
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

  Widget _buildChannelsList(List<MeshCoreChannel> channels, bool isLoading) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshChannels,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _ChannelCard(
                  channel: channel,
                  onTap: () => _showChannelDetails(channel),
                  onLongPress: () => _showChannelOptions(channel),
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

  Future<void> _refreshChannels() async {
    await ref.read(meshCoreChannelsProvider.notifier).refresh();
  }

  void _showCreateChannelDialog() {
    final nameController = TextEditingController();
    var isHashtag = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.card,
          title: const Text(
            'Create Channel',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Channel Name',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  hintText: isHashtag ? 'e.g. general' : 'Channel name',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  prefixText: isHashtag ? '#' : null,
                  prefixStyle: TextStyle(color: AccentColors.purple),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'Public Hashtag Channel',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  isHashtag
                      ? 'PSK derived from name (discoverable)'
                      : 'Random PSK (private)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                value: isHashtag,
                activeColor: AccentColors.purple,
                onChanged: (v) => setDialogState(() => isHashtag = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
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
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  showErrorSnackBar(ctx, 'Please enter a channel name');
                  return;
                }

                Navigator.pop(ctx);

                // Create channel with next available index
                final channelsState = ref.read(meshCoreChannelsProvider);
                final existingIndices = channelsState.channels
                    .map((c) => c.index)
                    .toSet();
                var newIndex = 0;
                for (var i = 0; i < 8; i++) {
                  if (!existingIndices.contains(i)) {
                    newIndex = i;
                    break;
                  }
                }

                final channel = isHashtag
                    ? MeshCoreChannel.publicChannel(newIndex, name)
                    : MeshCoreChannel(
                        index: newIndex,
                        name: name,
                        psk: Uint8List.fromList(List.generate(16, (i) => i)),
                      );

                await ref
                    .read(meshCoreChannelsProvider.notifier)
                    .setChannel(channel);

                if (mounted) {
                  showSuccessSnackBar(
                    context,
                    'Channel "${channel.name}" created',
                  );
                }
              },
              child: Text(
                'Create',
                style: TextStyle(color: AccentColors.purple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinChannelDialog() {
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join Channel',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildJoinOption(
            icon: Icons.tag_rounded,
            title: 'Join Hashtag Channel',
            subtitle: 'Enter channel name (e.g. #general)',
            onTap: () {
              Navigator.pop(context);
              _showJoinHashtagDialog();
            },
          ),
          _buildJoinOption(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan QR Code',
            subtitle: 'Scan a channel QR code',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MeshCoreQrScannerScreen(
                    mode: MeshCoreScanMode.channel,
                  ),
                ),
              );
            },
          ),
          _buildJoinOption(
            icon: Icons.keyboard_rounded,
            title: 'Enter Channel Code',
            subtitle: 'Paste a channel invite code',
            onTap: () {
              Navigator.pop(context);
              _showEnterCodeDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJoinOption({
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
          color: AccentColors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AccentColors.purple),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
      onTap: onTap,
    );
  }

  void _showJoinHashtagDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: const Text(
          'Join Hashtag Channel',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Channel Name',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            prefixText: '#',
            prefixStyle: TextStyle(color: AccentColors.purple),
            hintText: 'general',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white),
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
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                showErrorSnackBar(ctx, 'Please enter a channel name');
                return;
              }

              Navigator.pop(ctx);

              // Find next available index
              final channelsState = ref.read(meshCoreChannelsProvider);
              final existingIndices = channelsState.channels
                  .map((c) => c.index)
                  .toSet();
              var newIndex = 0;
              for (var i = 0; i < 8; i++) {
                if (!existingIndices.contains(i)) {
                  newIndex = i;
                  break;
                }
              }

              final channel = MeshCoreChannel.publicChannel(newIndex, name);
              await ref
                  .read(meshCoreChannelsProvider.notifier)
                  .setChannel(channel);

              if (mounted) {
                showSuccessSnackBar(context, 'Joined #$name');
              }
            },
            child: Text('Join', style: TextStyle(color: AccentColors.purple)),
          ),
        ],
      ),
    );
  }

  void _showEnterCodeDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: const Text(
          'Enter Channel Code',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Paste channel code here...',
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
              if (code.isEmpty) {
                showErrorSnackBar(ctx, 'Please enter a channel code');
                return;
              }

              // Find next available channel index
              final channelsState = ref.read(meshCoreChannelsProvider);
              final existingIndices = channelsState.channels
                  .map((c) => c.index)
                  .toSet();
              var newIndex = 0;
              for (var i = 0; i < 8; i++) {
                if (!existingIndices.contains(i)) {
                  newIndex = i;
                  break;
                }
              }

              final channel = parseChannelCode(code, index: newIndex);
              if (channel != null) {
                Navigator.pop(ctx);
                ref.read(meshCoreChannelsProvider.notifier).setChannel(channel);
                showSuccessSnackBar(context, 'Joined ${channel.displayName}');
              } else {
                showErrorSnackBar(
                  ctx,
                  'Invalid channel code format (expected: name:pskHex)',
                );
              }
            },
            child: Text('Join', style: TextStyle(color: AccentColors.purple)),
          ),
        ],
      ),
    );
  }

  void _showChannelDetails(MeshCoreChannel channel) {
    final channelCode = generateChannelCode(channel);

    QrShareSheet.show(
      context: context,
      title: channel.displayName,
      subtitle: channel.isPublic ? 'Public Channel' : 'Private Channel',
      qrData: channelCode,
      infoText: 'Scan this QR code to join the channel',
    );
  }

  void _showChannelOptions(MeshCoreChannel channel) {
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            channel.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_rounded, color: AccentColors.purple),
            title: const Text(
              'Open Channel',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      MeshCoreChatScreen.channel(channel: channel),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share_rounded, color: context.textSecondary),
            title: const Text(
              'Share Channel',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              final code = generateChannelCode(channel);
              Clipboard.setData(ClipboardData(text: code));
              showSuccessSnackBar(context, 'Channel code copied');
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_rounded, color: AppTheme.errorRed),
            title: Text(
              'Leave Channel',
              style: TextStyle(color: AppTheme.errorRed),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmLeaveChannel(channel);
            },
          ),
        ],
      ),
    );
  }

  void _confirmLeaveChannel(MeshCoreChannel channel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: const Text(
          'Leave Channel?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to leave ${channel.displayName}?',
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
            onPressed: () async {
              Navigator.pop(ctx);
              // Clear channel by setting empty name and default PSK
              await ref
                  .read(meshCoreChannelsProvider.notifier)
                  .setChannel(MeshCoreChannel.empty(channel.index));
              if (mounted) {
                showSuccessSnackBar(context, 'Left ${channel.displayName}');
              }
            },
            child: Text('Leave', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  void _disconnect() async {
    final coordinator = ref.read(connectionCoordinatorProvider);
    await coordinator.disconnect();
  }
}

/// Card widget for displaying a single channel.
class _ChannelCard extends StatelessWidget {
  final MeshCoreChannel channel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChannelCard({
    required this.channel,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isPublic = channel.isPublic;

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
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AccentColors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    isPublic ? Icons.tag_rounded : Icons.lock_rounded,
                    color: AccentColors.purple,
                    size: 24,
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
                      channel.displayName,
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
                          isPublic
                              ? Icons.public_rounded
                              : Icons.vpn_key_rounded,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPublic ? 'Public' : 'Private',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.memory_rounded,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Slot ${channel.index}',
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
              Icon(Icons.chevron_right_rounded, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
