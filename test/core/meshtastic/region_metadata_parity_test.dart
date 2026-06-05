// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshtastic/modem_preset_metadata.dart';
import 'package:socialmesh/core/meshtastic/region_metadata.dart';
import 'package:socialmesh/features/nodedex/models/observed_radio_preset.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart';

// Parity check between the protobuf-generated RegionCode and ModemPreset
// enums and the centralized metadata tables in
// `lib/core/meshtastic/`. When protobufs are regenerated and new enum
// values appear, the "every value is represented" tests fail until a
// matching metadata row is added.
//
// This test is the safety net that would have caught the seven-region
// drift between SocialMesh and the upstream protobuf during the v2.7.22
// → v2.7.23 bump (PH_433/868/915, ANZ_433, KZ_433/863, NP_865, BR_902
// were all in the protobuf but missing from the pickers).
void main() {
  group('RegionCode metadata parity', () {
    test('every protobuf RegionCode is in kRegionMetadata', () {
      final metadataCodes = kRegionMetadata.map((r) => r.code).toSet();
      final missing = Config_LoRaConfig_RegionCode.values
          .where((v) => !metadataCodes.contains(v))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'Add a RegionMetadata row for: ${missing.map((m) => m.name).join(", ")}',
      );
    });

    test('no duplicate RegionCode entries in kRegionMetadata', () {
      final seen = <Config_LoRaConfig_RegionCode>{};
      for (final r in kRegionMetadata) {
        expect(seen.add(r.code), isTrue, reason: 'Duplicate: ${r.code.name}');
      }
    });

    test(
      'kRegionMetadata is ordered by protobuf numeric value (UNSET first)',
      () {
        final values = kRegionMetadata.map((r) => r.code.value).toList();
        final sorted = [...values]..sort();
        expect(values, equals(sorted));
      },
    );

    test('dutyCycleForRegion returns 10 for all EU/UA SRD bands', () {
      const restricted = <Config_LoRaConfig_RegionCode>{
        Config_LoRaConfig_RegionCode.EU_433,
        Config_LoRaConfig_RegionCode.EU_868,
        Config_LoRaConfig_RegionCode.EU_866,
        Config_LoRaConfig_RegionCode.EU_874,
        Config_LoRaConfig_RegionCode.EU_917,
        Config_LoRaConfig_RegionCode.EU_N_868,
        Config_LoRaConfig_RegionCode.UA_433,
        Config_LoRaConfig_RegionCode.UA_868,
      };
      for (final r in restricted) {
        expect(dutyCycleForRegion(r), 10, reason: 'Region ${r.name}');
      }
    });

    test('dutyCycleForRegion returns 100 for ITU amateur-radio bands', () {
      expect(dutyCycleForRegion(Config_LoRaConfig_RegionCode.ITU1_2M), 100);
      expect(dutyCycleForRegion(Config_LoRaConfig_RegionCode.ITU2_2M), 100);
      expect(dutyCycleForRegion(Config_LoRaConfig_RegionCode.ITU3_2M), 100);
    });

    test('dutyCycleForRegion returns 0 for UNSET', () {
      expect(dutyCycleForRegion(Config_LoRaConfig_RegionCode.UNSET), 0);
    });

    test('regionMetadataFor resolves every code', () {
      for (final v in Config_LoRaConfig_RegionCode.values) {
        expect(regionMetadataFor(v), isNotNull, reason: v.name);
      }
    });
  });

  group('ModemPreset metadata parity', () {
    test('every protobuf ModemPreset is in kModemPresetMetadata', () {
      final metadataPresets = kModemPresetMetadata.map((p) => p.preset).toSet();
      final missing = Config_LoRaConfig_ModemPreset.values
          .where((v) => !metadataPresets.contains(v))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'Add a ModemPresetMetadata row for: ${missing.map((m) => m.name).join(", ")}',
      );
    });

    test('no duplicate ModemPreset entries in kModemPresetMetadata', () {
      final seen = <Config_LoRaConfig_ModemPreset>{};
      for (final p in kModemPresetMetadata) {
        expect(
          seen.add(p.preset),
          isTrue,
          reason: 'Duplicate: ${p.preset.name}',
        );
      }
    });

    test('modemPresetMetadataFor resolves every preset', () {
      for (final v in Config_LoRaConfig_ModemPreset.values) {
        expect(modemPresetMetadataFor(v), isNotNull, reason: v.name);
      }
    });
  });

  // ObservedRadioPreset is a parallel SQLite-persisted enum used by
  // NodeDex. It must stay in sync with the protobuf so that integer
  // values round-trip cleanly through nodedex.db. These tests fire when
  // a new ModemPreset lands in protobuf and ObservedRadioPreset hasn't
  // caught up.
  group('ObservedRadioPreset / protobuf parity', () {
    test('every protobuf ModemPreset has an ObservedRadioPreset entry', () {
      final observed = {
        for (final p in ObservedRadioPreset.values) p.protobufValue,
      };
      final missing = Config_LoRaConfig_ModemPreset.values
          .where((v) => !observed.contains(v.value))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'Add an ObservedRadioPreset entry for: ${missing.map((m) => "${m.name}(${m.value})").join(", ")}',
      );
    });

    test('ObservedRadioPreset.protobufEnum agrees with protobufValue', () {
      for (final p in ObservedRadioPreset.values) {
        expect(
          p.protobufEnum.value,
          p.protobufValue,
          reason:
              '${p.name}: protobufValue=${p.protobufValue} but '
              'protobufEnum=${p.protobufEnum.name}(${p.protobufEnum.value})',
        );
      }
    });
  });
}
