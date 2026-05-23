// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas participation settings value type.
//
// Source of truth: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §2.
//
// Three booleans, all defaulting `false`. They describe whether the
// user has acknowledged MeshCanvas (onboarding), whether mesh-side
// actions (paint enqueue / send / channel-list rendering) are
// allowed, and whether the local node may broadcast presence frames.
//
// Local Device Canvas is NEVER governed by these settings; the local
// sandbox remains free regardless of state.
//
// Mutation invariants are enforced in the notifier, not here. This
// type stays a dumb container so it round-trips through
// SharedPreferences and tests without leaking enforcement logic.
library;

import 'package:flutter/foundation.dart';

@immutable
class MeshCanvasParticipationSettings {
  /// The first-run onboarding sheet has been shown and dismissed.
  /// Monotonic: once `true`, never returns to `false` outside a
  /// destructive reset (out of scope for v0.1).
  final bool onboardingSeen;

  /// User opted into mesh paint + channel-canvas viewing. When
  /// `false`, the Mesh tab renders a single calm CTA card and no
  /// mesh paint / send / presence work is permitted.
  final bool participationEnabled;

  /// User opted into broadcasting their own presence frames. Always
  /// `false` when [participationEnabled] is `false` (enforced by the
  /// notifier).
  final bool presenceSharingEnabled;

  const MeshCanvasParticipationSettings({
    required this.onboardingSeen,
    required this.participationEnabled,
    required this.presenceSharingEnabled,
  });

  /// The conservative default: nothing seen, nothing enabled.
  static const MeshCanvasParticipationSettings initial =
      MeshCanvasParticipationSettings(
        onboardingSeen: false,
        participationEnabled: false,
        presenceSharingEnabled: false,
      );

  MeshCanvasParticipationSettings copyWith({
    bool? onboardingSeen,
    bool? participationEnabled,
    bool? presenceSharingEnabled,
  }) {
    return MeshCanvasParticipationSettings(
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      participationEnabled: participationEnabled ?? this.participationEnabled,
      presenceSharingEnabled:
          presenceSharingEnabled ?? this.presenceSharingEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MeshCanvasParticipationSettings &&
        other.onboardingSeen == onboardingSeen &&
        other.participationEnabled == participationEnabled &&
        other.presenceSharingEnabled == presenceSharingEnabled;
  }

  @override
  int get hashCode =>
      Object.hash(onboardingSeen, participationEnabled, presenceSharingEnabled);

  @override
  String toString() =>
      'MeshCanvasParticipationSettings(onboardingSeen: $onboardingSeen, '
      'participationEnabled: $participationEnabled, '
      'presenceSharingEnabled: $presenceSharingEnabled)';
}
