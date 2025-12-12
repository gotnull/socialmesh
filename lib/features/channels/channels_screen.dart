import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../messaging/messaging_screen.dart';
import '../navigation/main_shell.dart';
import 'channel_form_screen.dart';
import 'channel_wizard_screen.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: const Text(
          'Channels',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR code',
            onPressed: () {
              Navigator.of(context).pushNamed('/qr-import');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add channel',
            onPressed: () {
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: channels.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.wifi_tethering,
                      size: 40,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No channels configured',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Channels are still being loaded from device\nor use the icons above to add channels',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                final animationsEnabled = ref.watch(animationsEnabledProvider);
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
    final hasKey = channel.psk.isNotEmpty;

    return BouncyTap(
      onTap: () => _openChannelChat(context),
      onLongPress: () => _showChannelOptions(context, ref),
      scaleFactor: animationsEnabled ? 0.98 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? context.accentColor
                      : AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${channel.index}',
                    style: TextStyle(
                      color: isPrimary ? Colors.white : AppTheme.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                        color: Colors.white,
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
                              : AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasKey ? 'Encrypted' : 'No encryption',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
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
              const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
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
    final channelSettings = pb.ChannelSettings()
      ..name = channel.name
      ..psk = channel.psk;

    final pbChannel = pb.Channel()
      ..index = channel.index
      ..settings = channelSettings
      ..role = channel.index == 0
          ? pb.Channel_Role.PRIMARY
          : pb.Channel_Role.SECONDARY;

    // Encode as base64 and URL-encode for the URL fragment
    final base64Data = base64Encode(pbChannel.writeToBuffer());
    final channelUrl =
        'https://meshtastic.org/e/#${Uri.encodeComponent(base64Data)}';

    final channelName = channel.name.isEmpty
        ? 'Channel ${channel.index}'
        : channel.name;

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            icon: Icons.qr_code,
            title: channelName,
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
              label: const Text(
                'Copy Channel URL',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete channel "${channel.name}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.accentOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.accentOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your device will reboot after this change. The app will automatically reconnect.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: _showKey
              ? SelectableText(
                  widget.base64Key,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.accentColor,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    height: 1.5,
                  ),
                )
              : Text(
                  '•' * 32,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary.withValues(alpha: 0.5),
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showKey = !_showKey),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.darkBorder),
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
                  disabledBackgroundColor: AppTheme.darkBackground,
                  disabledForegroundColor: AppTheme.textTertiary.withValues(
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
