import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import 'channel_form_screen.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Channels',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChannelFormScreen(),
                ),
              );
            },
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
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Channels are still being loaded from device',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/qr-import');
                    },
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: AppTheme.primaryGreen,
                    ),
                    label: const Text(
                      'Scan QR Code',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _ChannelTile(channel: channel);
              },
            ),
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  final ChannelConfig channel;

  const _ChannelTile({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrimary = channel.index == 0;
    final hasKey = channel.psk.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showChannelOptions(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? AppTheme.primaryGreen
                        : AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${channel.index}',
                      style: TextStyle(
                        color: isPrimary
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
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
                            ? 'Channel ${channel.index}'
                            : channel.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            hasKey ? Icons.lock : Icons.lock_open,
                            size: 14,
                            color: hasKey
                                ? AppTheme.primaryGreen
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasKey ? 'Encrypted' : 'No encryption',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                          if (isPrimary) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                  fontFamily: 'Inter',
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
      ),
    );
  }

  void _showChannelOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text(
                'Edit Channel',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChannelFormScreen(
                      existingChannel: channel,
                      channelIndex: channel.index,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.key, color: Colors.white),
              title: const Text(
                'View Encryption Key',
                style: TextStyle(color: Colors.white),
              ),
              enabled: channel.psk.isNotEmpty,
              onTap: () {
                Navigator.pop(context);
                _showEncryptionKey(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.white),
              title: const Text(
                'Show QR Code',
                style: TextStyle(color: Colors.white),
              ),
              enabled: channel.psk.isNotEmpty,
              onTap: () {
                Navigator.pop(context);
                _showQrCode(context);
              },
            ),
            if (channel.index != 0)
              ListTile(
                leading: const Icon(Icons.delete, color: AppTheme.errorRed),
                title: const Text(
                  'Delete Channel',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteChannel(context, ref);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEncryptionKey(BuildContext context) {
    final base64Key = base64Encode(channel.psk);
    final keyBits = channel.psk.length * 8;
    bool showKey = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.key,
                        color: AppTheme.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Encryption Key',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$keyBits-bit · ${channel.psk.length} bytes · Base64',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textTertiary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Key display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: showKey
                      ? SelectableText(
                          base64Key,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.primaryGreen,
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

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() => showKey = !showKey);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.darkBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          showKey ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        label: Text(
                          showKey ? 'Hide' : 'Show',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: showKey
                            ? () {
                                Clipboard.setData(
                                  ClipboardData(text: base64Key),
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Key copied to clipboard'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppTheme.darkCard,
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.darkBackground,
                          disabledForegroundColor: AppTheme.textTertiary
                              .withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.copy, size: 20),
                        label: const Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQrCode(BuildContext context) {
    final base64Key = base64Encode(channel.psk);
    // Create Meshtastic URL format: https://meshtastic.org/e/#<base64_channel_config>
    final channelUrl =
        'https://meshtastic.org/e/#${Uri.encodeComponent(base64Key)}';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name.isEmpty
                              ? 'Channel ${channel.index}'
                              : channel.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Scan to join this channel',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // QR Code
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

              // Share button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: channelUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Channel URL copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppTheme.darkCard,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text(
                    'Copy Channel URL',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteChannel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Channel'),
        content: Text('Delete channel "${channel.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(channelsProvider.notifier)
                  .setChannel(
                    ChannelConfig(index: channel.index, name: '', psk: []),
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Channel deleted')));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
