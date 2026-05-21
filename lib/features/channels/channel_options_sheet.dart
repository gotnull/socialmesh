// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/channel.pbenum.dart' as channel_pbenum;
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/muted_channels_provider.dart';
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
      (channel.name.isEmpty
          ? context.l10n.channelOptionsDefaultName(channel.index)
          : channel.name);

  final isMuted = ref.read(mutedChannelsProvider).contains(channel.index);

  final actions = [
    BottomSheetAction(
      icon: isMuted ? Icons.notifications : Icons.notifications_off,
      label: isMuted
          ? context.l10n.channelOptionsUnmuteNotifications
          : context.l10n.channelOptionsMuteNotifications,
      value: 'mute',
    ),
    BottomSheetAction(
      icon: Icons.edit,
      label: context.l10n.channelOptionsEdit,
      value: 'edit',
    ),
    BottomSheetAction(
      icon: Icons.qr_code,
      label: context.l10n.channelOptionsViewQr,
      value: 'view_qr',
      enabled: channel.psk.isNotEmpty,
    ),
    BottomSheetAction(
      icon: Icons.key,
      label: context.l10n.channelOptionsViewKey,
      value: 'key',
      enabled: channel.psk.isNotEmpty,
    ),
    BottomSheetAction(
      icon: Icons.share,
      label: context.l10n.channelOptionsShare,
      value: 'qr',
      enabled: channel.psk.isNotEmpty,
    ),
    BottomSheetAction(
      icon: Icons.link,
      label: context.l10n.channelOptionsInviteLink,
      value: 'invite',
      enabled: channel.psk.isNotEmpty,
    ),
    BottomSheetAction(
      icon: Icons.delete_sweep,
      label: context.l10n.channelOptionsClearMessages,
      value: 'clear_messages',
      isDestructive: true,
    ),
    if (channel.index != 0)
      BottomSheetAction(
        icon: Icons.delete,
        label: context.l10n.channelOptionsDelete,
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
      subtitle: channel.psk.isNotEmpty
          ? context.l10n.channelOptionsEncrypted
          : context.l10n.channelOptionsNoEncryption,
    ),
  );

  if (result == null || !context.mounted) return;

  switch (result) {
    case 'mute':
      await ref.read(mutedChannelsProvider.notifier).toggleMute(channel.index);
    case 'view_qr':
      _showChannelQrCode(context, channel, channelName);
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
    case 'clear_messages':
      await _clearChannelMessages(context, channel, ref, channelName);
    case 'delete':
      _deleteChannel(context, channel, ref);
  }
}

/// Confirms and deletes every locally-stored message in this
/// channel. Local-only — does not affect any other device or
/// the radio. Mirrors the global "Clear Messages" pattern in
/// settings_screen.dart.
Future<void> _clearChannelMessages(
  BuildContext context,
  ChannelConfig channel,
  WidgetRef ref,
  String channelName,
) async {
  final confirmed = await AppBottomSheet.showConfirm(
    context: context,
    title: context.l10n.channelOptionsClearMessagesTitle,
    message: context.l10n.channelOptionsClearMessagesConfirmation,
    confirmLabel: context.l10n.channelOptionsClearMessagesConfirm,
    isDestructive: true,
  );
  if (confirmed != true || !context.mounted) return;

  await ref
      .read(messagesProvider.notifier)
      .deleteChannelMessages(channel.index);
  if (!context.mounted) return;
  showSuccessSnackBar(
    context,
    context.l10n.channelOptionsClearMessagesSuccess(channelName),
  );
}

/// Generates a local Meshtastic-compatible channel URL for QR sharing.
///
/// Encodes the channel settings (name, PSK, index, role) into a
/// protobuf-serialised, base64url-encoded URL that can be scanned
/// by any SocialMesh / Meshtastic client — fully offline.
String _generateChannelUrl(ChannelConfig channel) {
  final channelSettings = channel_pb.ChannelSettings()..name = channel.name;

  if (channel.psk.isNotEmpty) {
    channelSettings.psk = channel.psk;
  }

  final proto = channel_pb.Channel()
    ..index = channel.index
    ..settings = channelSettings
    ..role = channel.index == 0
        ? channel_pbenum.Channel_Role.PRIMARY
        : channel_pbenum.Channel_Role.SECONDARY;

  final bytes = proto.writeToBuffer();
  final encoded = base64Encode(bytes).replaceAll('+', '-').replaceAll('/', '_');
  return 'socialmesh://channel/$encoded'; // lint-allow: hardcoded-string
}

/// Shows the channel QR code bottom sheet for offline sharing.
void _showChannelQrCode(
  BuildContext context,
  ChannelConfig channel,
  String channelName,
) {
  final channelUrl = _generateChannelUrl(channel);

  QrShareSheet.show(
    context: context,
    title: channelName,
    subtitle: channel.psk.isNotEmpty
        ? context.l10n.channelOptionsEncrypted
        : context.l10n.channelOptionsNoEncryption,
    qrData: channelUrl,
    infoText: context.l10n.channelOptionsViewQrInfo,
  );
}

/// Shows the encryption key bottom sheet.
void _showEncryptionKey(BuildContext context, ChannelConfig channel) {
  AppBottomSheet.show(
    context: context,
    child: EncryptionKeyContent(channel: channel),
  );
}

/// Confirms and deletes a channel from the device.
Future<void> _deleteChannel(
  BuildContext context,
  ChannelConfig channel,
  WidgetRef ref,
) async {
  final connectionState = ref.read(connectionStateProvider);
  final isConnected = connectionState.maybeWhen(
    data: (state) => state == DeviceConnectionState.connected,
    orElse: () => false,
  );

  if (!isConnected) {
    showErrorSnackBar(context, context.l10n.channelOptionsDeleteNotConnected);
    return;
  }

  final confirmed = await AppBottomSheet.showConfirm(
    context: context,
    title: context.l10n.channelOptionsDeleteTitle,
    message: context.l10n.channelOptionsDeleteConfirm(channel.name),
    confirmLabel: context.l10n.channelOptionsDeleteButton,
    isDestructive: true,
  );
  if (confirmed != true || !context.mounted) return;

  final disabledChannel = ChannelConfig(
    index: channel.index,
    name: '',
    psk: [],
    uplink: false,
    downlink: false,
    role: 'DISABLED',
  );

  // Show an in-flight loading snackbar so the user sees that the
  // delete is being sent — without it the row only disappears once
  // the device round-trip completes, which can take a second or two.
  final messenger = ScaffoldMessenger.maybeOf(context);
  showLoadingSnackBar(
    context,
    context.l10n.channelOptionsDeleting,
    duration: const Duration(seconds: 15),
  );

  try {
    final protocol = ref.read(protocolServiceProvider);
    final channelsNotifier = ref.read(channelsProvider.notifier);
    await protocol.setChannel(disabledChannel);
    channelsNotifier.removeChannel(channel.index);
    messenger?.hideCurrentSnackBar();
    if (context.mounted) {
      showSuccessSnackBar(context, context.l10n.channelOptionsDeleted);
    }
  } catch (e) {
    messenger?.hideCurrentSnackBar();
    if (context.mounted) {
      showErrorSnackBar(
        context,
        context.l10n.channelOptionsDeleteFailed(e.toString()),
      );
    }
  }
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
          title: context.l10n.channelOptionsKeyTitle,
          subtitle: context.l10n.channelOptionsKeySubtitle(keyBits, keyBytes),
        ),
        const SizedBox(height: AppTheme.spacing20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
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
        const SizedBox(height: AppTheme.spacing16),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                icon: Icon(
                  _showKey ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                label: Text(
                  _showKey
                      ? context.l10n.channelOptionsHideButton
                      : context.l10n.channelOptionsShowButton,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showKey
                    ? () {
                        Clipboard.setData(ClipboardData(text: base64Key));
                        Navigator.pop(context);
                        showSuccessSnackBar(
                          context,
                          context.l10n.channelOptionsKeyCopied,
                        );
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
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                icon: const Icon(Icons.copy, size: 20),
                label: Text(
                  context.l10n.channelOptionsCopyButton,
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
