// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Decoded view of the region -> legal-preset map a 2.8+ radio sends once
// during the want_config handshake (`FromRadio.region_presets`). The wire
// shape is normalised: a list of preset groups plus one (region, group
// index) pair per region. Clients want the inverse, region -> info, so
// the LoRa config screen can constrain its preset picker to what is legal
// where the radio is set to operate. A region absent from the map carries
// no constraint and must not be restricted.

import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/mesh.pb.dart' as pb;

class RegionPresetInfo {
  const RegionPresetInfo({
    required this.presets,
    required this.defaultPreset,
    required this.licensedOnly,
  });

  /// Modem presets legal in this region, in the order the radio listed them.
  final List<config_pbenum.Config_LoRaConfig_ModemPreset> presets;

  /// The firmware default for this region. Always one of [presets] on a
  /// well-formed map; used when the current preset is not legal here.
  final config_pbenum.Config_LoRaConfig_ModemPreset defaultPreset;

  /// True for bands reserved for licensed operators (amateur radio).
  final bool licensedOnly;

  bool allows(config_pbenum.Config_LoRaConfig_ModemPreset preset) =>
      presets.contains(preset);
}

/// The modem preset the region picker writes alongside [to].
///
/// A first setup (region [from] UNSET) to US gets LONG_TURBO (500 kHz)
/// when the radio's map ([toInfo], the decoded entry for [to]) lists it as
/// legal there, matching the setup chooser in 2.8 firmware. Every other
/// choice gets LONG_FAST, including every radio without a map (pre-2.8
/// firmware).
config_pbenum.Config_LoRaConfig_ModemPreset presetForRegionChoice({
  required config_pbenum.Config_LoRaConfig_RegionCode? from,
  required config_pbenum.Config_LoRaConfig_RegionCode to,
  required RegionPresetInfo? toInfo,
}) {
  const turbo = config_pbenum.Config_LoRaConfig_ModemPreset.LONG_TURBO;
  final isFreshUsSetup =
      from == config_pbenum.Config_LoRaConfig_RegionCode.UNSET &&
      to == config_pbenum.Config_LoRaConfig_RegionCode.US;
  if (isFreshUsSetup && toInfo != null && toInfo.allows(turbo)) return turbo;
  return config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST;
}

/// Inverts [map] into a region -> info lookup.
///
/// Region entries pointing at a group index outside `groups`, and groups
/// with an empty preset list, are dropped: a malformed entry must read as
/// "no constraint" rather than "nothing is legal".
Map<config_pbenum.Config_LoRaConfig_RegionCode, RegionPresetInfo>
decodeRegionPresetMap(pb.LoRaRegionPresetMap map) {
  final result =
      <config_pbenum.Config_LoRaConfig_RegionCode, RegionPresetInfo>{};
  for (final entry in map.regionGroups) {
    final index = entry.groupIndex;
    if (index < 0 || index >= map.groups.length) continue;
    final group = map.groups[index];
    if (group.presets.isEmpty) continue;
    result[entry.region] = RegionPresetInfo(
      presets: List.unmodifiable(group.presets),
      defaultPreset: group.presets.contains(group.defaultPreset)
          ? group.defaultPreset
          : group.presets.first,
      licensedOnly: group.licensedOnly,
    );
  }
  return result;
}
