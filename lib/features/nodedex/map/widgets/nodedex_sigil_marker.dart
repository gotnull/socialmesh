// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex-specific map marker.
//
// Visually unique from the canonical mesh-node `_NodeMarker` so users
// can tell at a glance that NodeDex Map markers are remembered
// encounters from their journal, not live mesh nodes:
//
//   - sigil avatar at the centre (always present, generated from
//     nodeNum if no `SigilData` is cached)
//   - thin gradient "memory ring" tinted by social tag (or default
//     purple when untagged) — the live `_NodeMarker` has a flat
//     outline, so the swept gradient + glow is the differentiator
//   - selected state thickens the ring and brightens the glow
//   - stale state (last positioned encounter > 7 days old) drops the
//     marker to ~60 % opacity so the ring fades but stays legible
//
// The marker is purely presentational — taps are handled by the
// surrounding `GestureDetector` in `MapScreen`.

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../models/nodedex_entry.dart';
import '../../widgets/sigil_painter.dart';
import '../nodedex_map_pin.dart';

const double _kBaseSize = 40;
const double _kSelectedSize = 48;
const double _kBaseSigilSize = 30;
const double _kSelectedSigilSize = 36;
const double _kBaseRingPadding = 2;
const double _kSelectedRingPadding = 3;
const double _kStaleOpacity = 0.6;
const double _kBaseGlowBlur = 6;
const double _kSelectedGlowBlur = 12;

class NodeDexSigilMarker extends StatelessWidget {
  final NodeDexMapPin pin;
  final bool isSelected;
  final bool isStale;

  const NodeDexSigilMarker({
    super.key,
    required this.pin,
    required this.isSelected,
    required this.isStale,
  });

  Color _ringColor() {
    final tag = pin.socialTag;
    if (tag == null) return AppTheme.primaryPurple;
    return switch (tag) {
      NodeSocialTag.contact => AccentColors.sky,
      NodeSocialTag.trustedNode => AccentColors.emerald,
      NodeSocialTag.knownRelay => AccentColors.orange,
      NodeSocialTag.frequentPeer => AppTheme.primaryPurple,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ring = _ringColor();
    final size = isSelected ? _kSelectedSize : _kBaseSize;
    final sigilSize = isSelected ? _kSelectedSigilSize : _kBaseSigilSize;
    final ringPadding = isSelected ? _kSelectedRingPadding : _kBaseRingPadding;
    final glowBlur = isSelected ? _kSelectedGlowBlur : _kBaseGlowBlur;
    final glowSpread = isSelected ? 1.0 : 0.0;

    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Swept gradient gives a subtle "rotating memory" feel
        // distinct from the flat outline on _NodeMarker.
        gradient: SweepGradient(
          colors: [
            ring,
            ring.withValues(alpha: 0.45),
            ring,
            ring.withValues(alpha: 0.45),
            ring,
          ],
          stops: const [0, 0.25, 0.5, 0.75, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: ring.withValues(alpha: 0.45),
            blurRadius: glowBlur,
            spreadRadius: glowSpread,
          ),
        ],
      ),
      padding: EdgeInsets.all(ringPadding),
      child: ClipOval(
        child: Container(
          color: context.background,
          padding: const EdgeInsets.all(AppTheme.spacing1),
          child: SigilAvatar(
            nodeNum: pin.nodeNum,
            sigil: pin.sigil,
            size: sigilSize,
          ),
        ),
      ),
    );

    if (!isStale) return core;
    return Opacity(opacity: _kStaleOpacity, child: core);
  }
}
