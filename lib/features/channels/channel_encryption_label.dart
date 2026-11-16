// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../models/mesh_models.dart';

/// The name shown for a channel's [ChannelEncryption] in the channel list,
/// its options sheet and its QR share sheet.
String channelEncryptionLabel(
  BuildContext context,
  ChannelEncryption encryption,
) => switch (encryption) {
  ChannelEncryption.none => context.l10n.channelsTileNoEncryption,
  ChannelEncryption.publicKey => context.l10n.channelsTileDefaultKey,
  ChannelEncryption.privateKey => context.l10n.channelsTileEncrypted,
};

/// The lock shown beside a channel in the channel list. A channel with its
/// own key gets a closed lock. One with no key or the public default key
/// gets an open lock, red when it shares precise location (position
/// precision of 17 to 32 bits, which anyone on the channel can read) and
/// red with a warning when it also uplinks that to MQTT.
({IconData icon, Color color}) channelLockStyle(
  ChannelConfig channel,
  ChannelEncryption encryption,
) {
  if (encryption == ChannelEncryption.privateKey) {
    return (icon: Icons.lock, color: SemanticColors.success);
  }
  final precise =
      channel.positionPrecision >= 17 && channel.positionPrecision <= 32;
  if (precise && channel.uplink) {
    return (
      icon: Icons.no_encryption_gmailerrorred,
      color: SemanticColors.error,
    );
  }
  if (precise) return (icon: Icons.lock_open, color: SemanticColors.error);
  return (icon: Icons.lock_open, color: SemanticColors.warning);
}
