// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshtastic/region_presets.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart';

void main() {
  group('decodeRegionPresetMap', () {
    test('inverts groups into a region lookup with default and licensing', () {
      final map = LoRaRegionPresetMap()
        ..groups.addAll([
          LoRaPresetGroup()
            ..presets.addAll([
              Config_LoRaConfig_ModemPreset.LONG_FAST,
              Config_LoRaConfig_ModemPreset.LONG_TURBO,
              Config_LoRaConfig_ModemPreset.MEDIUM_TURBO,
            ])
            ..defaultPreset = Config_LoRaConfig_ModemPreset.LONG_TURBO,
          LoRaPresetGroup()
            ..presets.addAll([
              Config_LoRaConfig_ModemPreset.TINY_FAST,
              Config_LoRaConfig_ModemPreset.TINY_SLOW,
            ])
            ..defaultPreset = Config_LoRaConfig_ModemPreset.TINY_FAST
            ..licensedOnly = true,
        ])
        ..regionGroups.addAll([
          LoRaRegionPresets()
            ..region = Config_LoRaConfig_RegionCode.US
            ..groupIndex = 0,
          LoRaRegionPresets()
            ..region = Config_LoRaConfig_RegionCode.ITU2_2M
            ..groupIndex = 1,
        ]);

      final decoded = decodeRegionPresetMap(map);

      final us = decoded[Config_LoRaConfig_RegionCode.US]!;
      expect(us.defaultPreset, Config_LoRaConfig_ModemPreset.LONG_TURBO);
      expect(us.licensedOnly, isFalse);
      expect(us.allows(Config_LoRaConfig_ModemPreset.MEDIUM_TURBO), isTrue);
      expect(us.allows(Config_LoRaConfig_ModemPreset.TINY_FAST), isFalse);

      final ham = decoded[Config_LoRaConfig_RegionCode.ITU2_2M]!;
      expect(ham.licensedOnly, isTrue);
      expect(ham.presets, hasLength(2));

      // A region the radio said nothing about carries no constraint.
      expect(decoded.containsKey(Config_LoRaConfig_RegionCode.EU_868), isFalse);
    });

    test('drops malformed entries instead of forbidding everything', () {
      final map = LoRaRegionPresetMap()
        ..groups.addAll([
          LoRaPresetGroup(), // empty preset list
          LoRaPresetGroup()
            ..presets.add(Config_LoRaConfig_ModemPreset.LONG_FAST)
            // Default not in the list: fall back to the first legal preset.
            ..defaultPreset = Config_LoRaConfig_ModemPreset.SHORT_FAST,
        ])
        ..regionGroups.addAll([
          LoRaRegionPresets()
            ..region = Config_LoRaConfig_RegionCode.EU_868
            ..groupIndex = 0,
          LoRaRegionPresets()
            ..region = Config_LoRaConfig_RegionCode.ANZ
            ..groupIndex = 7, // out of range
          LoRaRegionPresets()
            ..region = Config_LoRaConfig_RegionCode.JP
            ..groupIndex = 1,
        ]);

      final decoded = decodeRegionPresetMap(map);

      expect(decoded.containsKey(Config_LoRaConfig_RegionCode.EU_868), isFalse);
      expect(decoded.containsKey(Config_LoRaConfig_RegionCode.ANZ), isFalse);
      expect(
        decoded[Config_LoRaConfig_RegionCode.JP]!.defaultPreset,
        Config_LoRaConfig_ModemPreset.LONG_FAST,
      );
    });

    test('an empty map decodes to no constraints', () {
      expect(decodeRegionPresetMap(LoRaRegionPresetMap()), isEmpty);
    });
  });
}
