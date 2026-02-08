// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
import 'channel_form_screen.dart';
import 'channel_share_utils.dart';

/// Shows the unified channel options bottom sheet.
///
/// Used from both the channels list (long-press) and the messaging
/// screen (settings icon). One implementation, one set of options.
Future<void> showChannelOptionsSheet(
  BuildContext context,
  ChannelConfig channel, {
  required WidgetRef ref,
  String? displayTitle,
}) async {
  final channelName =
      displayTitle ??
      (channel.name.isEmpty ? 'Channel ${channel.index}' : channel.name);

  final actions = [
    BottomSheetAction(icon: Icons.edit, label: 'Edit Channel', value: 'edit'),
    BottomSheetAction(
      icon: Icons.key,
      label: 'View Encryption Key',
      value: 'key',
      enabled: channel.psk.isNotEmpty,
    ),
    BottomSheetAction(
      icon: Icons.share,
      label: 'Share Channel',
      value: 'qr',
      enabled: channel.psk.isNotEmpty,
    ),
    BottomSheetAction(
      icon: Icons.link,
      label: 'Share Invite Link',
      value: 'invite',
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
    header: BottomSheetHeader(
      icon: Icons.wifi_tethering,
      title: channelName,
      subtitle: channel.psk.isNotEmpty ? 'Encrypted' : 'No encryption',
    ),
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
    case 'key':
      _showEncryptionKey(context, channel);
    case 'qr':
      showChannelShareSheet(
        context,
        channel,
        ref: ref,
        displayTitle: displayTitle,
      );
    case 'invite':
      await shareChannelInviteLink(
        context,
        channel,
        ref: ref,
        displayTitle: displayTitle,
      );
    case 'delete':
      _deleteChannel(context, channel, ref);
  }
}

/// Shows the encryption key bottom sheet.
void _showEncryptionKey(BuildContext context, ChannelConfig channel) {
  AppBottomSheet.show(
    context: context,
    child: EncryptionKeyContent(channel: channel),
  );
}

/// Confirms and deletes a channel from the device.
void _deleteChannel(
  BuildContext context,
  ChannelConfig channel,
  WidgetRef ref,
) {
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

            final disabledChannel = ChannelConfig(
              index: channel.index,
              name: '',
              psk: [],
              uplink: false,
              downlink: false,
              role: 'DISABLED',
            );

            try {
              final protocol = ref.read(protocolServiceProvider);
              final channelsNotifier = ref.read(channelsProvider.notifier);
              await protocol.setChannel(disabledChannel);
              channelsNotifier.removeChannel(channel.index);
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

/// Encryption key viewer widget.
///
/// Shared between channels list and messaging screen.
class EncryptionKeyContent extends StatefulWidget {
  final ChannelConfig channel;

  const EncryptionKeyContent({super.key, required this.channel});

  @override
  State<EncryptionKeyContent> createState() => _EncryptionKeyContentState();
}

class _EncryptionKeyContentState extends State<EncryptionKeyContent> {
  bool _showKey = false;

  @override
  Widget build(BuildContext context) {
    final base64Key = base64Encode(widget.channel.psk);
    final keyBits = widget.channel.psk.length * 8;
    final keyBytes = widget.channel.psk.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          icon: Icons.key,
          title: 'Encryption Key',
          subtitle: '$keyBits-bit · $keyBytes bytes · Base64',
        ),
        const SizedBox(height: 20),
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
                  base64Key,
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
        const SizedBox(height: 16),
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
                        Clipboard.setData(ClipboardData(text: base64Key));
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
                label: Text(
                  'Copy',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
