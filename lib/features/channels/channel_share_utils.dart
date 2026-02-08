// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../models/mesh_models.dart';
import '../../providers/auth_providers.dart';
import '../../services/channel_crypto_service.dart';
import '../../services/channel_invite_service.dart';
import '../../utils/snackbar.dart';

/// Show a bottom sheet with QR code and share options for a channel.
/// Uploads channel metadata (without PSK) to Firestore, encrypts the PSK
/// per-member, and generates a shareable link.
/// Requires user to be signed in for cloud sharing features.
Future<void> showChannelShareSheet(
  BuildContext context,
  ChannelConfig channel, {
  required WidgetRef ref,
  String? displayTitle,
}) async {
  // Check if user is signed in
  final user = ref.read(currentUserProvider);
  if (user == null) {
    showActionSnackBar(
      context,
      'Sign in to share channels',
      actionLabel: 'Sign In',
      onAction: () => Navigator.pushNamed(context, '/account'),
      type: SnackBarType.info,
    );
    return;
  }

  final userId = user.uid;
  final cryptoService = ref.read(channelCryptoServiceProvider);
  final channelName =
      displayTitle ??
      (channel.name.isEmpty ? 'Channel ${channel.index}' : channel.name);

  await QrShareSheet.showWithLoader(
    context: context,
    title: 'Share Channel',
    subtitle: channelName,
    infoText: 'Scan this QR code in Socialmesh to import this channel',
    shareSubject: 'Socialmesh Channel: $channelName',
    shareMessage: 'Join my channel on Socialmesh!',
    loader: () => _uploadAndGetShareData(channel, userId, cryptoService),
  );
}

/// Share a channel via an invite link.
///
/// Creates a time-limited, usage-limited invite on the server and
/// copies a URL to the clipboard. The URL contains the invite secret
/// in the fragment (never sent to server).
Future<void> shareChannelInviteLink(
  BuildContext context,
  ChannelConfig channel, {
  required WidgetRef ref,
  String? displayTitle,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null) {
    showActionSnackBar(
      context,
      'Sign in to share channels',
      actionLabel: 'Sign In',
      onAction: () => Navigator.pushNamed(context, '/account'),
      type: SnackBarType.info,
    );
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final channelName =
      displayTitle ??
      (channel.name.isEmpty ? 'Channel ${channel.index}' : channel.name);

  try {
    // Ensure the channel is shared (creates metadata + owner key blob)
    final cryptoService = ref.read(channelCryptoServiceProvider);
    final docId = await cryptoService.shareChannelSecurely(
      channel: channel,
      ownerUid: user.uid,
    );

    // Create an invite via Cloud Function
    final inviteService = ref.read(channelInviteServiceProvider);
    final invite = await inviteService.createInvite(
      channelId: docId,
      label: channelName,
    );

    // Copy the invite URL to clipboard
    await Clipboard.setData(ClipboardData(text: invite.shareUrl));

    AppLogging.channels(
      '[ChannelShare] Created invite link for "$channelName" '
      '(invite ${invite.inviteId})',
    );

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    AppLogging.channels('[ChannelShare] Invite link error: $e');
    messenger.showSnackBar(
      SnackBar(
        content: Text('Failed to create invite: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Uploads channel securely and returns share data for QR sheet.
/// PSK is encrypted per-member and never stored in plaintext.
Future<QrShareData> _uploadAndGetShareData(
  ChannelConfig channel,
  String userId,
  ChannelCryptoService cryptoService,
) async {
  final docId = await cryptoService.shareChannelSecurely(
    channel: channel,
    ownerUid: userId,
  );

  AppLogging.channels(
    '[ChannelShare] Securely shared channel "${channel.name}" '
    'with ID $docId (PSK encrypted, not stored in plaintext)',
  );

  // Generate URLs
  final shareUrl = AppUrls.shareChannelUrl(docId);
  final deepLink = 'socialmesh://channel/id:$docId';

  return QrShareData(qrData: deepLink, shareUrl: shareUrl);
}
