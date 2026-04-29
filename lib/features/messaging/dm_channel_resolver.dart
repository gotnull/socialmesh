// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../core/logging.dart';
import '../../models/mesh_models.dart';

/// Result of a DM channel resolution.
///
/// Carries the channel index that goes on the wire plus the recipient's
/// curve25519 public key (when available) so the caller can attach
/// `pki_encrypted = true` + `publicKey = …` to the outbound MeshPacket —
/// matching the official Meshtastic iOS app's DM send path
/// (`AccessoryManager+ToRadio.swift:327-329`, `360`).
class DmChannelResolution {
  final int channel;
  final List<int>? publicKey;

  /// Identifier of the parity rule that picked this resolution. Stable
  /// across releases so log lines remain greppable.
  ///
  /// - `'ios_parity_dm_default'` — iOS hard-codes channel `0` for any
  ///   `MessageDestination.user(_)` (`MessageDestination.swift:13-18`),
  ///   regardless of last-heard channel index, hopsAway, or NodeDB
  ///   metadata. This is the only resolution iOS produces for DMs.
  /// - `'ios_parity_no_node_metadata'` — recipient is unknown to the
  ///   nodes provider. iOS falls back to channel `0` with no PKI key —
  ///   so do we.
  final String source;

  const DmChannelResolution({
    required this.channel,
    required this.source,
    this.publicKey,
  });

  bool get hasPki => publicKey != null && publicKey!.isNotEmpty;
}

/// Resolves the channel index and PKI public-key bytes for an outbound
/// direct message to [destinationNodeId].
///
/// **Parity reference:** `meshtastic-ios` 2.7.x, two files:
///   - `Meshtastic/Enums/MessageDestination.swift:13-18` — `.user`
///     returns `0` for `channelNum`. No NodeDB lookup, no last-heard
///     index, no hash matching, no multi-channel handling. The iOS app
///     ALWAYS hard-codes `0` on the wire for any DM.
///   - `Meshtastic/Accessory/Accessory Manager/AccessoryManager+ToRadio.swift:327-329, 360`
///     — `meshPacket.channel = UInt32(channel)` writes the value
///     verbatim (no firmware-side override). When the recipient's
///     `UserEntity.pkiEncrypted` is true, `meshPacket.pkiEncrypted` and
///     `meshPacket.publicKey` are also set; the firmware then encrypts
///     the payload with PKI and ignores the channel PSK.
///
/// **Multiple-channel handling:** N/A — iOS doesn't consider this. The
/// wire `channel` field is always `0` for DMs.
///
/// **Fallback when no metadata:** still `0`. Same as iOS.
///
/// **Why this resolver exists if it always returns 0:** so the call site
/// in `messaging_screen.dart` is no longer a literal `channel: 0`
/// hard-code. Future iOS-parity updates land in this one function, and
/// every DM gets a structured `MESSAGES_DM_CHANNEL_RESOLVED` log line
/// with the destination, picked channel, source rule, and PKI-key
/// availability — observable from the in-app log viewer / Crashlytics
/// breadcrumbs.
DmChannelResolution resolveDmChannel({
  required int destinationNodeId,
  required MeshNode? destinationNode,
}) {
  if (destinationNode == null) {
    AppLogging.messages(
      'MESSAGES_DM_CHANNEL_RESOLVED '
      'destination=0x${destinationNodeId.toRadixString(16)} '
      'channel=0 source=ios_parity_no_node_metadata pkiAttached=false',
    );
    return const DmChannelResolution(
      channel: 0,
      source: 'ios_parity_no_node_metadata',
    );
  }

  final pubKey =
      destinationNode.publicKey != null && destinationNode.publicKey!.isNotEmpty
      ? destinationNode.publicKey
      : null;

  AppLogging.messages(
    'MESSAGES_DM_CHANNEL_RESOLVED '
    'destination=0x${destinationNodeId.toRadixString(16)} '
    'channel=0 source=ios_parity_dm_default '
    'pkiAttached=${pubKey != null} '
    'publicKeyLen=${pubKey?.length ?? 0} '
    'hasPublicKeyFlag=${destinationNode.hasPublicKey}',
  );

  return DmChannelResolution(
    channel: 0,
    source: 'ios_parity_dm_default',
    publicKey: pubKey,
  );
}
