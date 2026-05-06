// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D26 — region preset table regression pins.
//
// The 19 presets each pin (frequencyMHz, bandwidthKhz, sf, cr,
// txPowerDbm). Wrong values can put a user out of regulatory band
// or off the active mesh frequency, so a future "preset table
// cleanup" must come with a deliberate test update rather than
// silently shifting numbers. Also pins the matching helper used to
// resolve "what preset is the user currently on" without storing
// extra state per chip.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';

void main() {
  group('D26 region preset table', () {
    test('exactly 19 presets', () {
      expect(kMeshCoreRegionPresets.length, equals(19));
    });

    test('preset ids are unique and snake_case', () {
      final ids = kMeshCoreRegionPresets.map((p) => p.id).toList();
      expect(
        ids.toSet().length,
        equals(ids.length),
        reason: 'duplicate preset ids — would break persistence hydration',
      );
      for (final id in ids) {
        expect(
          RegExp(r'^[a-z0-9_]+$').hasMatch(id),
          isTrue,
          reason: 'preset id "$id" must be snake_case for stable persistence',
        );
      }
    });

    test('Custom sentinel id is reserved and NOT in the preset list', () {
      expect(
        kMeshCoreRegionPresets.any((p) => p.id == kMeshCoreCustomPresetId),
        isFalse,
        reason: 'Custom is a UI-only sentinel; never store it as a preset',
      );
    });

    // Spot-check a handful of presets against the recon-source table.
    // Anchored to the values verified against the meshcore-open
    // reference repo at audit time. Adding new presets is fine; the
    // anchored tuples must stay byte-stable.
    test('Australia (default): 915.8 / 250 / SF10 / 4/5 / 20 dBm', () {
      final p = kMeshCoreRegionPresets.firstWhere((p) => p.id == 'au_default');
      expect(p.frequencyMHz, equals(915.8));
      expect(p.bandwidthKhz, equals(250));
      expect(p.spreadingFactor, equals(10));
      expect(p.codingRate, equals(5));
      expect(p.txPowerDbm, equals(20));
      expect(p.label, equals('Australia'));
    });

    test('EU/UK (Long Range): 869.525 / 250 / SF11 / 4/5 / 14 dBm', () {
      final p = kMeshCoreRegionPresets.firstWhere(
        (p) => p.id == 'eu_uk_long_range',
      );
      expect(p.frequencyMHz, equals(869.525));
      expect(p.bandwidthKhz, equals(250));
      expect(p.spreadingFactor, equals(11));
      expect(p.codingRate, equals(5));
      expect(p.txPowerDbm, equals(14));
    });

    test('USA/Canada: 910.525 / 62.5 / SF7 / 4/5 / 20 dBm', () {
      final p = kMeshCoreRegionPresets.firstWhere((p) => p.id == 'us_canada');
      expect(p.frequencyMHz, equals(910.525));
      expect(p.bandwidthKhz, equals(62.5));
      expect(p.spreadingFactor, equals(7));
      expect(p.codingRate, equals(5));
      expect(p.txPowerDbm, equals(20));
    });

    test('Off-Grid 869: 869.0 / 250 / SF11 / 4/8 / 14 dBm', () {
      final p = kMeshCoreRegionPresets.firstWhere((p) => p.id == 'offgrid_869');
      expect(p.frequencyMHz, equals(869.0));
      expect(p.bandwidthKhz, equals(250));
      expect(p.spreadingFactor, equals(11));
      expect(p.codingRate, equals(8));
      expect(p.txPowerDbm, equals(14));
    });

    test('coding rates are within firmware-supported range [5..8]', () {
      for (final p in kMeshCoreRegionPresets) {
        expect(p.codingRate, greaterThanOrEqualTo(5));
        expect(p.codingRate, lessThanOrEqualTo(8));
      }
    });

    test('spreading factors are within firmware-supported range [5..12]', () {
      for (final p in kMeshCoreRegionPresets) {
        expect(p.spreadingFactor, greaterThanOrEqualTo(5));
        expect(p.spreadingFactor, lessThanOrEqualTo(12));
      }
    });

    test('TX power dBm values are within firmware bounds [-9..30]', () {
      // `setRadioTxPower` rejects outside this range.
      for (final p in kMeshCoreRegionPresets) {
        expect(p.txPowerDbm, greaterThanOrEqualTo(-9));
        expect(p.txPowerDbm, lessThanOrEqualTo(30));
      }
    });
  });

  group('D26 meshCoreRegionPresetMatching', () {
    test('exact-tuple match returns the preset', () {
      final result = meshCoreRegionPresetMatching(
        frequencyMHz: 915.8,
        bandwidthKhz: 250,
        spreadingFactor: 10,
        codingRate: 5,
        txPowerDbm: 20,
      );
      expect(result?.id, equals('au_default'));
    });

    test('returns null when no preset matches (custom user config)', () {
      final result = meshCoreRegionPresetMatching(
        frequencyMHz: 868.0, // not in any preset
        bandwidthKhz: 125, // also off-preset
        spreadingFactor: 9,
        codingRate: 5,
        txPowerDbm: 20,
      );
      expect(result, isNull);
    });

    test('absorbs sub-kHz frequency rounding (0.001 MHz tolerance)', () {
      // 915.8 ± 0.0009 → still matches (within 1 kHz).
      final result = meshCoreRegionPresetMatching(
        frequencyMHz: 915.8009,
        bandwidthKhz: 250,
        spreadingFactor: 10,
        codingRate: 5,
        txPowerDbm: 20,
      );
      expect(result?.id, equals('au_default'));
    });

    test('absorbs 62.5 / 125 / 250 bandwidth float roundoff', () {
      // 62.499 reads as 62.5 within the 0.5 kHz tolerance.
      final result = meshCoreRegionPresetMatching(
        frequencyMHz: 869.618,
        bandwidthKhz: 62.499,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 14,
      );
      expect(result?.id, equals('eu_uk_narrow'));
    });

    test('SF / CR mismatch returns null even with matching freq+bw', () {
      // EU/UK Long Range freq+bw, but SF12 (custom).
      final result = meshCoreRegionPresetMatching(
        frequencyMHz: 869.525,
        bandwidthKhz: 250,
        spreadingFactor: 12,
        codingRate: 5,
        txPowerDbm: 14,
      );
      expect(result, isNull);
    });

    test('TX power mismatch returns null', () {
      // EU/UK Long Range tuple but tx=20 instead of 14.
      final result = meshCoreRegionPresetMatching(
        frequencyMHz: 869.525,
        bandwidthKhz: 250,
        spreadingFactor: 11,
        codingRate: 5,
        txPowerDbm: 20,
      );
      expect(result, isNull);
    });
  });

  group('D26 lat/lon scale', () {
    test('kMeshCoreAdvertLatLonScale is exactly 1e6 (NOT Meshtastic 1e7)', () {
      expect(kMeshCoreAdvertLatLonScale, equals(1000000));
    });
  });

  group('D26 max node name bytes', () {
    test('matches firmware buffer (32 - null terminator = 31)', () {
      expect(kMeshCoreMaxNodeNameBytes, equals(31));
    });
  });
}
