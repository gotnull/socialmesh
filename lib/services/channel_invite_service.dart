// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../models/mesh_models.dart';
import '../providers/auth_providers.dart';

/// Result of creating a channel invite.
class ChannelInviteResult {
  const ChannelInviteResult({
    required this.inviteId,
    required this.inviteSecret,
  });

  final String inviteId;
  final String inviteSecret;

  /// Build the share URL with the secret in the fragment.
  /// Format: `https://socialmesh.app/share/channel/{inviteId}#t={secret}`
  String get shareUrl => '${AppUrls.shareChannelUrl(inviteId)}#t=$inviteSecret';
}

/// Result of redeeming a channel invite.
class ChannelRedeemResult {
  const ChannelRedeemResult({
    required this.channelId,
    required this.channel,
    required this.alreadyMember,
  });

  final String channelId;
  final ChannelConfig channel;
  final bool alreadyMember;
}

/// Service for creating and redeeming channel invite links.
///
/// All operations go through Cloud Functions — the client never
/// reads or writes `channel_invites` documents directly.
class ChannelInviteService {
  ChannelInviteService(this._ref);

  final Ref _ref;

  /// Create an invite link for a channel.
  ///
  /// Returns the invite ID and secret. The caller builds the URL as:
  ///   `https://socialmesh.app/share/channel/{inviteId}#t={secret}`
  ///
  /// Only the channel owner may call this.
  Future<ChannelInviteResult> createInvite({
    required String channelId,
    int expiresInHours = 72,
    int maxUses = 0,
    String? label,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw StateError('Not authenticated');

    final callable = FirebaseFunctions.instance.httpsCallable(
      'createChannelInvite',
    );

    final result = await callable.call<dynamic>({
      'channelId': channelId,
      'expiresInHours': expiresInHours,
      'maxUses': maxUses,
      if (label != null) 'label': label,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    AppLogging.channels(
      '[ChannelInvite] Created invite ${data['inviteId']} '
      'for channel $channelId',
    );

    return ChannelInviteResult(
      inviteId: data['inviteId'] as String,
      inviteSecret: data['inviteSecret'] as String,
    );
  }

  /// Redeem an invite link.
  ///
  /// [inviteId] is the path segment from the URL.
  /// [inviteSecret] is extracted from the URL fragment (#t=...).
  ///
  /// On success, the server adds the user as a member and creates
  /// their encrypted key blob. Returns channel metadata.
  Future<ChannelRedeemResult> redeemInvite({
    required String inviteId,
    required String inviteSecret,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw StateError('Not authenticated');

    final callable = FirebaseFunctions.instance.httpsCallable(
      'redeemChannelInvite',
    );

    final result = await callable.call<dynamic>({
      'inviteId': inviteId,
      'inviteSecret': inviteSecret,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final channelMap = Map<String, dynamic>.from(data['channel'] as Map);
    final channelId = data['channelId'] as String;

    AppLogging.channels(
      '[ChannelInvite] Redeemed invite $inviteId → channel $channelId',
    );

    return ChannelRedeemResult(
      channelId: channelId,
      channel: ChannelConfig(
        index: channelMap['index'] as int? ?? 0,
        name: channelMap['name'] as String? ?? '',
        psk: const [], // PSK is fetched separately via ChannelCryptoService
        uplink: channelMap['uplink'] as bool? ?? false,
        downlink: channelMap['downlink'] as bool? ?? false,
        role: channelMap['role'] as String? ?? 'SECONDARY',
        positionPrecision: channelMap['positionPrecision'] as int? ?? 0,
      ),
      alreadyMember: data['alreadyMember'] as bool? ?? false,
    );
  }

  /// Revoke an invite. Only the creator can revoke.
  Future<void> revokeInvite({required String inviteId}) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'revokeChannelInvite',
    );

    await callable.call<dynamic>({'inviteId': inviteId});

    AppLogging.channels('[ChannelInvite] Revoked invite $inviteId');
  }
}

/// Provider for the channel invite service.
final channelInviteServiceProvider = Provider<ChannelInviteService>((ref) {
  return ChannelInviteService(ref);
});
