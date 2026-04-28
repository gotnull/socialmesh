// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Centralized ModemPreset metadata. One row per Meshtastic
// `Config_LoRaConfig_ModemPreset`. The radio_config_screen modem
// preset selector reads from [kModemPresetMetadata]. Adding a new
// preset is one entry plus one ARB key per locale — no per-screen
// edits. Mirrors the Apple iOS app's `enum ModemPresets:
// CaseIterable` from
// `meshtastic-ios/Meshtastic/Enums/LoraConfigEnums.swift`.

import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import 'region_metadata.dart' show LocalizedStringFn;

class ModemPresetMetadata {
  const ModemPresetMetadata({
    required this.preset,
    required this.label,
    required this.description,
  });

  final config_pbenum.Config_LoRaConfig_ModemPreset preset;
  final LocalizedStringFn label;
  final LocalizedStringFn description;
}

// Ordered as they appear in the picker — protobuf-numeric except for
// VERY_LONG_SLOW (deprecated upstream in 2.5 but still surfaced for
// users who already have it set; iOS hides it entirely).
final List<ModemPresetMetadata> kModemPresetMetadata = <ModemPresetMetadata>[
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
    label: (l) => l.radioConfigPresetLongFast,
    description: (l) => l.radioConfigPresetLongFastDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_SLOW,
    label: (l) => l.radioConfigPresetLongSlow,
    description: (l) => l.radioConfigPresetLongSlowDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.VERY_LONG_SLOW,
    label: (l) => l.radioConfigPresetVeryLongSlow,
    description: (l) => l.radioConfigPresetVeryLongSlowDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE,
    label: (l) => l.radioConfigPresetLongModerate,
    description: (l) => l.radioConfigPresetLongModerateDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
    label: (l) => l.radioConfigPresetMediumFast,
    description: (l) => l.radioConfigPresetMediumFastDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_SLOW,
    label: (l) => l.radioConfigPresetMediumSlow,
    description: (l) => l.radioConfigPresetMediumSlowDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST,
    label: (l) => l.radioConfigPresetShortFast,
    description: (l) => l.radioConfigPresetShortFastDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_SLOW,
    label: (l) => l.radioConfigPresetShortSlow,
    description: (l) => l.radioConfigPresetShortSlowDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_TURBO,
    label: (l) => l.radioConfigPresetShortTurbo,
    description: (l) => l.radioConfigPresetShortTurboDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_TURBO,
    label: (l) => l.radioConfigPresetLongTurbo,
    description: (l) => l.radioConfigPresetLongTurboDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LITE_FAST,
    label: (l) => l.radioConfigPresetLiteFast,
    description: (l) => l.radioConfigPresetLiteFastDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.LITE_SLOW,
    label: (l) => l.radioConfigPresetLiteSlow,
    description: (l) => l.radioConfigPresetLiteSlowDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.NARROW_FAST,
    label: (l) => l.radioConfigPresetNarrowFast,
    description: (l) => l.radioConfigPresetNarrowFastDesc,
  ),
  ModemPresetMetadata(
    preset: config_pbenum.Config_LoRaConfig_ModemPreset.NARROW_SLOW,
    label: (l) => l.radioConfigPresetNarrowSlow,
    description: (l) => l.radioConfigPresetNarrowSlowDesc,
  ),
];

final Map<config_pbenum.Config_LoRaConfig_ModemPreset, ModemPresetMetadata>
_presetByEnum = {for (final p in kModemPresetMetadata) p.preset: p};

ModemPresetMetadata? modemPresetMetadataFor(
  config_pbenum.Config_LoRaConfig_ModemPreset preset,
) => _presetByEnum[preset];
