// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../nodedex/services/sigil_generator.dart';
import '../../nodedex/widgets/sigil_painter.dart';

/// Sigil avatar keyed on a MeshCore node's 32-byte Ed25519 public key.
///
/// Wraps [SigilAvatar] with a pubkey-derived [SigilData]. The first 4
/// bytes of the pubkey are interpreted as a uint32 seed via the same
/// [SigilGenerator.generateFromPersonaId] pipeline already used for SIP
/// persona ids; this keeps the visual style identical to Meshtastic
/// sigils while keying off MeshCore's native identity.
///
/// Tap behaviour is opt-in (Meshtastic's [TappableSigilAvatar] defaults
/// to navigating to NodeDexDetailScreen, but MeshCore has no NodeDex
/// counterpart - the device sheet is the "this is me" surface).
class MeshCoreSigilAvatar extends StatelessWidget {
  /// The MeshCore node's 32-byte public key. The first 4 bytes seed the
  /// sigil; the remaining bytes are unused for sigil generation but
  /// kept here so callers don't have to slice.
  ///
  /// Asserts at construction that the buffer is at least 4 bytes long.
  final Uint8List pubKey;

  /// Rendered diameter (matches [SigilAvatar.size]). Defaults to 44 to
  /// match Meshtastic's default; pass 56 for drawer headers (Meshtastic
  /// uses 56 for its drawer self-header).
  final double size;

  /// Optional badge widget to overlay on the avatar (status dot, etc.).
  final Widget? badge;

  /// Tap callback. When null, the avatar is non-interactive. Callers
  /// in "this is me" contexts (drawer self-header) typically pass a
  /// callback that opens the MeshCore device sheet; contact tiles can
  /// pass a callback that opens the chat or a contact detail sheet.
  final VoidCallback? onTap;

  const MeshCoreSigilAvatar({
    super.key,
    required this.pubKey,
    this.size = 44,
    this.badge,
    this.onTap,
  }) : assert(
         pubKey.length >= 4,
         'MeshCore pubkey must be at least 4 bytes to seed a sigil', // lint-allow: hardcoded-string
       );

  @override
  Widget build(BuildContext context) {
    final sigil = SigilGenerator.generateFromPersonaId(pubKey);
    final avatar = SigilAvatar(sigil: sigil, size: size, badge: badge);

    if (onTap == null) return avatar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: avatar,
    );
  }
}
