// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetNeedIndicator — a floating thought-bubble icon that tells the
// user AT A GLANCE what the pet wants. Mirrors the "_drawZzz" trick
// (a floating Z-glyph painted above the pet when asleep) but for
// every other call reason: hungry → bowl, lonely → heart, sick →
// medical cross, bedtime → crescent moon, boredom → question mark.
// Hygiene is intentionally omitted here because the dirt artefacts
// already draw on the field and a thought-bubble on top would
// double-signal.
//
// Designed as an overlay widget (Stack sibling of the creature) so it
// works equally for the Rive-based creature and the painter fallback
// — no need to edit the .riv file for this class of hint.
//
// Pulse animation: the bubble fades/scales gently on a 1.2-second
// loop; subtle enough to read as ambient, aggressive enough to catch
// the eye when the pet actually needs attention.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/pet_enums.dart';

class PetNeedIndicator extends StatefulWidget {
  /// The active call reason. When null, the widget renders `SizedBox`
  /// and does not drive its controller — no animation cost at rest.
  final CallReason? reason;

  /// Creature size in logical pixels. Used to position the bubble
  /// above and slightly to the right of the creature so it reads as
  /// a thought bubble.
  final double creatureSize;

  const PetNeedIndicator({
    super.key,
    required this.reason,
    required this.creatureSize,
  });

  @override
  State<PetNeedIndicator> createState() => _PetNeedIndicatorState();
}

class _PetNeedIndicatorState extends State<PetNeedIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.reason != null) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PetNeedIndicator old) {
    super.didUpdateWidget(old);
    if (widget.reason != null && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (widget.reason == null && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.reason;
    if (reason == null) return const SizedBox.shrink();

    final data = _dataFor(reason);
    // Position: above + right of creature, in the classic
    // thought-bubble slot. The creature is centered in a
    // `creatureSize × creatureSize` box, so we offset from that
    // origin.
    final offset = Offset(
      widget.creatureSize * 0.24,
      -widget.creatureSize * 0.38,
    );
    return Transform.translate(
      offset: offset,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          final scale = 0.92 + 0.10 * t;
          final glowAlpha = 0.18 + 0.22 * t;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: data.color.withValues(alpha: glowAlpha),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 2,
                ),
              ),
              child: Icon(data.icon, size: 24, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  _NeedVisual _dataFor(CallReason reason) {
    switch (reason) {
      case CallReason.hungry:
        return _NeedVisual(Icons.restaurant, AccentColors.yellow);
      case CallReason.lonely:
        return _NeedVisual(Icons.favorite, AccentColors.pink);
      case CallReason.sick:
        return _NeedVisual(Icons.medical_services, AccentColors.red);
      case CallReason.hygiene:
        // Kept for completeness even though the caller usually passes
        // null for hygiene (dirt artefacts handle this visual channel).
        return _NeedVisual(Icons.cleaning_services, AccentColors.teal);
      case CallReason.bedtime:
        return _NeedVisual(Icons.nightlight_round, AccentColors.indigo);
      case CallReason.boredom:
        return _NeedVisual(Icons.sentiment_dissatisfied, AccentColors.lavender);
    }
  }
}

class _NeedVisual {
  final IconData icon;
  final Color color;
  const _NeedVisual(this.icon, this.color);
}
