// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Observed Radio Preset — canonical app-level modem preset representation.
//
// This enum mirrors the protobuf Config_LoRaConfig_ModemPreset values
// (0–9) for stable SQLite persistence, while providing:
// - Human-readable localized labels for UI display
// - Graceful handling of unknown/future values
// - Decoupling from auto-generated protobuf code
//
// Semantic note: When associated with a node observation, this
// represents the preset of the *local* radio at the time the node was
// detected — NOT the remote node's own preset. We cannot know a remote
// node's modem preset from received packets alone. Name accordingly:
// lastObservedOnPreset, observedOnPreset.

import 'package:flutter/material.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

/// Canonical app-level representation of a Meshtastic modem preset.
///
/// This enum mirrors the protobuf `Config_LoRaConfig_ModemPreset` values
/// (0–9) for stable SQLite persistence, while providing:
/// - Human-readable localized labels for UI display
/// - Graceful handling of unknown/future values
/// - Decoupling from auto-generated protobuf code
///
/// **Semantic note**: When associated with a node observation, this
/// represents the preset of the *local* radio at the time the node was
/// detected — NOT the remote node's own preset. We cannot know a remote
/// node's modem preset from received packets alone. Name accordingly:
/// `lastObservedOnPreset`, `observedOnPreset`.
enum ObservedRadioPreset {
  /// Long range, fast data rate. Protobuf value: 0.
  longFast(0),

  /// Long range, slow data rate (deprecated upstream 2.7). Protobuf value: 1.
  longSlow(1),

  /// Very long range, very slow data rate (deprecated upstream 2.5).
  /// Protobuf value: 2.
  veryLongSlow(2),

  /// Medium range, slow data rate. Protobuf value: 3.
  mediumSlow(3),

  /// Medium range, fast data rate. Protobuf value: 4.
  mediumFast(4),

  /// Short range, slow data rate. Protobuf value: 5.
  shortSlow(5),

  /// Short range, fast data rate. Protobuf value: 6.
  shortFast(6),

  /// Long range, moderate data rate. Protobuf value: 7.
  longModerate(7),

  /// Short range, turbo data rate. Protobuf value: 8.
  shortTurbo(8),

  /// Long range, turbo data rate. Protobuf value: 9.
  longTurbo(9);

  /// The integer value matching `Config_LoRaConfig_ModemPreset.value`.
  /// Used for SQLite persistence and protobuf interop.
  final int protobufValue;

  const ObservedRadioPreset(this.protobufValue);

  /// Index for reverse-lookup from persisted integer values.
  static final Map<int, ObservedRadioPreset> _byValue = {
    for (final preset in values) preset.protobufValue: preset,
  };

  /// Resolve from a protobuf integer value.
  ///
  /// Returns `null` for unknown/unmapped values — callers must handle
  /// gracefully (e.g. display "Unknown" in UI, skip in filters).
  static ObservedRadioPreset? fromProtobufValue(int? value) {
    if (value == null) return null;
    return _byValue[value];
  }

  /// Localized human-readable label for UI display.
  ///
  /// Falls back to a formatted enum name if l10n key is missing (defensive).
  String label(AppLocalizations l10n) {
    return switch (this) {
      ObservedRadioPreset.longFast => l10n.radioConfigPresetLongFast,
      ObservedRadioPreset.longSlow => l10n.radioConfigPresetLongSlow,
      ObservedRadioPreset.veryLongSlow => l10n.radioConfigPresetVeryLongSlow,
      ObservedRadioPreset.mediumSlow => l10n.radioConfigPresetMediumSlow,
      ObservedRadioPreset.mediumFast => l10n.radioConfigPresetMediumFast,
      ObservedRadioPreset.shortSlow => l10n.radioConfigPresetShortSlow,
      ObservedRadioPreset.shortFast => l10n.radioConfigPresetShortFast,
      ObservedRadioPreset.longModerate => l10n.radioConfigPresetLongModerate,
      ObservedRadioPreset.shortTurbo => l10n.radioConfigPresetShortTurbo,
      ObservedRadioPreset.longTurbo => l10n.radioConfigPresetLongTurbo,
    };
  }

  /// Accent color for UI chips and filter indicators.
  Color get color => AccentColors.emerald;
}
