// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshtastic/modem_preset_metadata.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart';

void main() {
  group('bandwidthKhz', () {
    test('only the three turbo presets run at 500 kHz', () {
      final wide = kModemPresetMetadata
          .where((p) => p.bandwidthKhz >= 500)
          .map((p) => p.preset)
          .toSet();
      expect(wide, {
        Config_LoRaConfig_ModemPreset.SHORT_TURBO,
        Config_LoRaConfig_ModemPreset.MEDIUM_TURBO,
        Config_LoRaConfig_ModemPreset.LONG_TURBO,
      });
    });

    test('matches the firmware table for the common presets', () {
      double bw(Config_LoRaConfig_ModemPreset p) =>
          modemPresetMetadataFor(p)!.bandwidthKhz;
      expect(bw(Config_LoRaConfig_ModemPreset.LONG_FAST), 250);
      expect(bw(Config_LoRaConfig_ModemPreset.MEDIUM_FAST), 250);
      expect(bw(Config_LoRaConfig_ModemPreset.LONG_SLOW), 125);
      expect(bw(Config_LoRaConfig_ModemPreset.NARROW_FAST), 62.5);
      expect(bw(Config_LoRaConfig_ModemPreset.TINY_FAST), 15.6);
    });
  });

  group('isUsBelow500KhzBandwidth', () {
    bool check({
      Config_LoRaConfig_RegionCode? region = Config_LoRaConfig_RegionCode.US,
      bool usePreset = true,
      Config_LoRaConfig_ModemPreset? preset,
      int bandwidth = 0,
    }) => isUsBelow500KhzBandwidth(
      region: region,
      usePreset: usePreset,
      preset: preset,
      customBandwidthCode: bandwidth,
    );

    test('US on a 250 kHz preset is flagged', () {
      expect(check(preset: Config_LoRaConfig_ModemPreset.LONG_FAST), isTrue);
      expect(check(preset: Config_LoRaConfig_ModemPreset.MEDIUM_FAST), isTrue);
    });

    test('US on a narrower preset is flagged', () {
      expect(check(preset: Config_LoRaConfig_ModemPreset.LONG_SLOW), isTrue);
      expect(check(preset: Config_LoRaConfig_ModemPreset.NARROW_FAST), isTrue);
    });

    test('US on a 500 kHz preset is not flagged', () {
      expect(check(preset: Config_LoRaConfig_ModemPreset.LONG_TURBO), isFalse);
      expect(check(preset: Config_LoRaConfig_ModemPreset.SHORT_TURBO), isFalse);
      expect(
        check(preset: Config_LoRaConfig_ModemPreset.MEDIUM_TURBO),
        isFalse,
      );
    });

    test('US custom bandwidth is judged by the configured value', () {
      // 0 is the firmware default of 250 kHz.
      expect(check(usePreset: false, bandwidth: 0), isTrue);
      expect(check(usePreset: false, bandwidth: 250), isTrue);
      expect(check(usePreset: false, bandwidth: 62), isTrue);
      expect(check(usePreset: false, bandwidth: 500), isFalse);
    });

    test('custom mode ignores the stored preset', () {
      expect(
        check(
          usePreset: false,
          preset: Config_LoRaConfig_ModemPreset.LONG_TURBO,
          bandwidth: 125,
        ),
        isTrue,
      );
      expect(
        check(
          usePreset: false,
          preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
          bandwidth: 500,
        ),
        isFalse,
      );
    });

    test('other regions are never flagged', () {
      for (final region in [
        Config_LoRaConfig_RegionCode.EU_868,
        Config_LoRaConfig_RegionCode.ANZ,
        Config_LoRaConfig_RegionCode.BR_902,
        Config_LoRaConfig_RegionCode.UNSET,
        null,
      ]) {
        expect(
          check(
            region: region,
            preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
          ),
          isFalse,
          reason: '$region',
        );
        expect(
          check(region: region, usePreset: false, bandwidth: 125),
          isFalse,
          reason: '$region custom',
        );
      }
    });

    test('no preset loaded yet is not flagged', () {
      expect(check(), isFalse);
    });
  });
}
