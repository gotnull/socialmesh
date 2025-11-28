import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';

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
            onPressed: () => _showAddChannelDialog(context, ref),
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

  void _showAddChannelDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final pskController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                hintText: 'e.g., LongFast',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pskController,
              decoration: const InputDecoration(
                labelText: 'Pre-Shared Key (Base64)',
                hintText: 'Leave empty for default',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a channel name')),
                );
                return;
              }

              List<int> psk = [];
              final pskText = pskController.text.trim();
              if (pskText.isNotEmpty) {
                try {
                  psk = base64Decode(pskText);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid Base64 PSK')),
                  );
                  return;
                }
              }

              final channels = ref.read(channelsProvider);
              final newChannel = ChannelConfig(
                index: channels.length,
                name: name,
                psk: psk,
              );

              ref.read(channelsProvider.notifier).setChannel(newChannel);

              if (psk.isNotEmpty) {
                final secureStorage = ref.read(secureStorageProvider);
                await secureStorage.storeChannelKey(name, psk);
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Channel "$name" added')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
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
                      color: isPrimary ? Colors.white : AppTheme.textSecondary,
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
    );
  }

  void _showChannelOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Channel Details'),
            onTap: () {
              Navigator.pop(context);
              _showChannelDetails(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Channel'),
            onTap: () {
              Navigator.pop(context);
              _editChannel(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('View Encryption Key'),
            enabled: channel.psk.isNotEmpty,
            onTap: () {
              Navigator.pop(context);
              _showEncryptionKey(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Change Encryption Key'),
            onTap: () {
              Navigator.pop(context);
              _changeEncryptionKey(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Show QR Code'),
            enabled: channel.psk.isNotEmpty,
            onTap: () {
              Navigator.pop(context);
              _showQrCode(context);
            },
          ),
          if (channel.index != 0)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Channel'),
              onTap: () {
                Navigator.pop(context);
                _deleteChannel(context, ref);
              },
            ),
        ],
      ),
    );
  }

  void _editChannel(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: channel.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                hintText: 'e.g., LongFast',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final updatedChannel = ChannelConfig(
                index: channel.index,
                name: name,
                psk: channel.psk,
                uplink: channel.uplink,
                downlink: channel.downlink,
              );

              ref.read(channelsProvider.notifier).setChannel(updatedChannel);

              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Channel updated')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changeEncryptionKey(BuildContext context, WidgetRef ref) {
    final pskController = TextEditingController(
      text: channel.psk.isNotEmpty ? base64Encode(channel.psk) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Encryption Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter new Pre-Shared Key (Base64)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pskController,
              decoration: const InputDecoration(
                labelText: 'PSK (Base64)',
                hintText: 'Leave empty to remove encryption',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'WARNING: Changing the key will prevent communication with nodes using the old key.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              List<int> psk = [];
              final pskText = pskController.text.trim();

              if (pskText.isNotEmpty) {
                try {
                  psk = base64Decode(pskText);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid Base64 PSK')),
                  );
                  return;
                }
              }

              final updatedChannel = ChannelConfig(
                index: channel.index,
                name: channel.name,
                psk: psk,
                uplink: channel.uplink,
                downlink: channel.downlink,
              );

              ref.read(channelsProvider.notifier).setChannel(updatedChannel);

              if (psk.isNotEmpty) {
                final secureStorage = ref.read(secureStorageProvider);
                await secureStorage.storeChannelKey(
                  channel.name.isEmpty
                      ? 'Channel ${channel.index}'
                      : channel.name,
                  psk,
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Encryption key updated')),
                );
              }
            },
            child: const Text('Update Key'),
          ),
        ],
      ),
    );
  }

  void _showChannelDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          channel.name.isEmpty ? 'Channel ${channel.index}' : channel.name,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Index', value: '${channel.index}'),
            _DetailRow(
              label: 'Name',
              value: channel.name.isEmpty ? 'Unnamed' : channel.name,
            ),
            _DetailRow(
              label: 'Encryption',
              value: channel.psk.isNotEmpty ? 'Enabled' : 'Disabled',
            ),
            _DetailRow(
              label: 'Uplink',
              value: channel.uplink ? 'Enabled' : 'Disabled',
            ),
            _DetailRow(
              label: 'Downlink',
              value: channel.downlink ? 'Enabled' : 'Disabled',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEncryptionKey(BuildContext context) {
    final base64Key = base64Encode(channel.psk);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encryption Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Base64 PSK:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              base64Key,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              '${channel.psk.length} bytes',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: base64Key));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Key copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showQrCode(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR code generation coming soon')),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
