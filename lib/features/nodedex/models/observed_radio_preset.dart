// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Observed Radio Preset — canonical app-level modem preset representation.
//
// Mirrors the protobuf Config_LoRaConfig_ModemPreset values (0–13 as of
// v2.7.23) for stable SQLite persistence in nodedex.db, while providing:
// - Human-readable localized labels for UI display (delegated to the
//   centralized kModemPresetMetadata source of truth)
// - Graceful handling of unknown/future protobuf values
// - Decoupling from auto-generated protobuf code at the persistence layer
//
// Semantic note: When associated with a node observation, this
// represents the preset of the *local* radio at the time the node was
// detected — NOT the remote node's own preset. We cannot know a remote
// node's modem preset from received packets alone. Name accordingly:
// lastObservedOnPreset, observedOnPreset.

import 'package:flutter/material.dart';
import 'package:socialmesh/core/meshtastic/modem_preset_metadata.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/l10n/app_localizations.dart';

/// Canonical app-level representation of a Meshtastic modem preset.
///
/// Mirrors the protobuf `Config_LoRaConfig_ModemPreset` values (0–13 as
/// of v2.7.23) for stable SQLite persistence, while providing:
/// - Human-readable localized labels (via [kModemPresetMetadata])
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
  longFast(0, config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST),

  /// Long range, slow data rate (deprecated upstream 2.7). Protobuf value: 1.
  longSlow(1, config_pbenum.Config_LoRaConfig_ModemPreset.LONG_SLOW),

  /// Very long range, very slow data rate (deprecated upstream 2.5).
  /// Protobuf value: 2.
  veryLongSlow(2, config_pbenum.Config_LoRaConfig_ModemPreset.VERY_LONG_SLOW),

  /// Medium range, slow data rate. Protobuf value: 3.
  mediumSlow(3, config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_SLOW),

  /// Medium range, fast data rate. Protobuf value: 4.
  mediumFast(4, config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST),

  /// Short range, slow data rate. Protobuf value: 5.
  shortSlow(5, config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_SLOW),

  /// Short range, fast data rate. Protobuf value: 6.
  shortFast(6, config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST),

  /// Long range, moderate data rate. Protobuf value: 7.
  longModerate(7, config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE),

  /// Short range, turbo data rate. Protobuf value: 8.
  shortTurbo(8, config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_TURBO),

  /// Long range, turbo data rate. Protobuf value: 9.
  longTurbo(9, config_pbenum.Config_LoRaConfig_ModemPreset.LONG_TURBO),

  /// EU 866MHz SRD, MEDIUM_FAST-comparable. New in protobufs v2.7.23.
  /// Protobuf value: 10.
  liteFast(10, config_pbenum.Config_LoRaConfig_ModemPreset.LITE_FAST),

  /// EU 866MHz SRD, LONG_FAST-comparable. New in protobufs v2.7.23.
  /// Protobuf value: 11.
  liteSlow(11, config_pbenum.Config_LoRaConfig_ModemPreset.LITE_SLOW),

  /// EU 868MHz narrow (62.5 kHz). New in protobufs v2.7.23.
  /// Protobuf value: 12.
  narrowFast(12, config_pbenum.Config_LoRaConfig_ModemPreset.NARROW_FAST),

  /// EU 868MHz narrow (62.5 kHz). New in protobufs v2.7.23.
  /// Protobuf value: 13.
  narrowSlow(13, config_pbenum.Config_LoRaConfig_ModemPreset.NARROW_SLOW);

  /// The integer value matching `Config_LoRaConfig_ModemPreset.value`.
  /// Used for SQLite persistence and protobuf interop.
  final int protobufValue;

  /// Strongly-typed protobuf enum — used to look up shared metadata.
  final config_pbenum.Config_LoRaConfig_ModemPreset protobufEnum;

  const ObservedRadioPreset(this.protobufValue, this.protobufEnum);

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

  /// Localized human-readable label for UI display. Single source of
  /// truth — pulls from [kModemPresetMetadata] so the radio config
  /// picker and the NodeDex chips always match.
  String label(AppLocalizations l10n) =>
      modemPresetMetadataFor(protobufEnum)!.label(l10n);

  /// Accent color for UI chips and filter indicators.
  Color get color => AccentColors.emerald;
}
