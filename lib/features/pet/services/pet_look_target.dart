// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetLookTargetResolver — pure-Dart mapping from a local widget-space
// pointer offset + current pet state flags to the bounded (0..100)
// look targets the Rive state machine consumes via `lookX` / `lookY`.
//
// Kept separate from the widget so:
//   1. The math is unit-testable without mounting the Rive runtime.
//   2. Raw pointer coordinates never reach the Rive layer — only the
//      normalised, range-scaled, clamped output does.
//
// State-driven modulation (behaviour rules, see assets/pet/README.md):
//
//   - dormant  : suppressed — always (50, 50).
//   - asleep   : suppressed — always (50, 50).
//   - sick     : reduced range around centre (sluggish, dampened).
//   - calling  : slightly stronger range (more alert).
//   - content  : full range (default).
//
// Priority: dormant > asleep > sick > calling > content.

import 'package:flutter/foundation.dart';

import '../models/pet_enums.dart';

/// Bounded (0..100) look target consumed by the Rive state machine.
@immutable
class PetLookTarget {
  final double x;
  final double y;

  const PetLookTarget(this.x, this.y);

  /// Neutral centre — the documented idle default for `lookX`/`lookY`.
  static const PetLookTarget center = PetLookTarget(50.0, 50.0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetLookTarget && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'PetLookTarget(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Computes the look target from a local pointer offset and the current
/// pet state flags. Pure — no Flutter widgets, no Rive runtime.
class PetLookTargetResolver {
  const PetLookTargetResolver();

  /// Range-scale applied to the symmetric offset from centre for each
  /// state. 1.0 = full edge-to-edge travel; < 1.0 = dampened; 0.0 =
  /// locked to centre.
  static const double _rangeScaleContent = 1.0;
  static const double _rangeScaleCalling = 1.1;
  static const double _rangeScaleSick = 0.55;

  /// Resolve a bounded target for the Rive layer.
  ///
  /// [localPointer] is the pointer position in the creature widget's
  /// own coordinate space (top-left origin). Pass `null` when there is
  /// no active pointer (idle) — the resolver returns centre.
  ///
  /// [size] is the creature widget's extent; both axes use the same
  /// bound. Non-positive sizes short-circuit to centre.
  PetLookTarget resolve({
    required ({double dx, double dy})? localPointer,
    required double size,
    required bool isAsleep,
    required bool isSick,
    required bool isCalling,
    required PetStage stage,
  }) {
    // Suppression states — ignore the pointer entirely.
    if (stage == PetStage.dormant) return PetLookTarget.center;
    if (isAsleep) return PetLookTarget.center;
    if (size <= 0) return PetLookTarget.center;
    if (localPointer == null) return PetLookTarget.center;

    // Normalise local (0..size) → symmetric (-1..+1) around the centre
    // so the range-scale is applied symmetrically.
    final nx = ((localPointer.dx / size) * 2.0 - 1.0).clamp(-1.0, 1.0);
    final ny = ((localPointer.dy / size) * 2.0 - 1.0).clamp(-1.0, 1.0);

    // Behaviour priority: sick dampens tracking even if also calling;
    // calling amplifies only when healthy.
    final double rangeScale;
    if (isSick) {
      rangeScale = _rangeScaleSick;
    } else if (isCalling) {
      rangeScale = _rangeScaleCalling;
    } else {
      rangeScale = _rangeScaleContent;
    }

    final lookX = (50.0 + nx * 50.0 * rangeScale).clamp(0.0, 100.0);
    final lookY = (50.0 + ny * 50.0 * rangeScale).clamp(0.0, 100.0);
    return PetLookTarget(lookX, lookY);
  }
}

/// Smoothed runtime value that eases toward a target each frame. Kept
/// here (and not in the widget file) so the easing math has the same
/// testable boundary as the resolver.
class PetLookSmoother {
  /// Base lerp factor per frame at ~60fps. Higher = snappier. Chosen
  /// so the creature reaches ~95% of a new target in ~150ms, which
  /// reads as responsive but not twitchy.
  static const double _baseLerp = 0.18;

  /// Sick/dormant easing back to centre is slower — sluggish feel.
  static const double _sluggishLerp = 0.08;

  /// How much the current and target must differ (on the 0..100 scale)
  /// before we push a new value to the Rive runtime. Below this we
  /// skip the write to keep the state machine stable.
  static const double _materialEpsilon = 0.25;

  double _currentX = 50.0;
  double _currentY = 50.0;

  double get currentX => _currentX;
  double get currentY => _currentY;

  /// Reset to centre without easing — used when the controller rebinds.
  void resetToCenter() {
    _currentX = 50.0;
    _currentY = 50.0;
  }

  /// Advance one frame toward the supplied target. Returns `true` when
  /// the delta since the last applied value is material, signalling the
  /// caller should push the new `currentX` / `currentY` into Rive.
  bool tick({required PetLookTarget target, required bool sluggish}) {
    final lerp = sluggish ? _sluggishLerp : _baseLerp;
    final prevX = _currentX;
    final prevY = _currentY;
    _currentX += (target.x - _currentX) * lerp;
    _currentY += (target.y - _currentY) * lerp;
    final material =
        (_currentX - prevX).abs() >= _materialEpsilon ||
        (_currentY - prevY).abs() >= _materialEpsilon ||
        // Snap when we cross the epsilon to exact target — prevents
        // the lerp from asymptoting below the write threshold and
        // stranding the Rive value a hair off centre.
        ((target.x - _currentX).abs() < _materialEpsilon &&
            (target.x - prevX).abs() >= _materialEpsilon) ||
        ((target.y - _currentY).abs() < _materialEpsilon &&
            (target.y - prevY).abs() >= _materialEpsilon);
    if (material &&
        (target.x - _currentX).abs() < _materialEpsilon &&
        (target.y - _currentY).abs() < _materialEpsilon) {
      _currentX = target.x;
      _currentY = target.y;
    }
    return material;
  }
}
