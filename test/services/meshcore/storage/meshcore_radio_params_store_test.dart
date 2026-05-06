// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Tests for MeshCoreRadioParamsStore.
//
// Validates D11 client-side persistence: the bug the user hit was that
// re-opening the Radio Settings sheet showed empty freq + default
// bandwidth because nothing on the client remembered the just-applied
// values (SelfInfo doesn't carry freq/bw). The store fixes this by
// keying SharedPreferences on the device pubkey hex so two physically
// distinct radios never overwrite each other.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_radio_params_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreRadioParams toJson/fromJson', () {
    test('round-trips canonical values', () {
      const original = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 22,
      );
      final restored = MeshCoreRadioParams.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('survives negative TX power (signed int8 semantics)', () {
      const original = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: -5,
      );
      final restored = MeshCoreRadioParams.fromJson(original.toJson());
      expect(restored.txPowerDbm, -5);
    });
  });

  group('MeshCoreRadioParamsStore', () {
    test('save then load round-trips for a single node', () async {
      final store = MeshCoreRadioParamsStore();
      const params = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 22,
      );

      await store.save('79426D8D', params);
      final loaded = await store.load('79426D8D');

      expect(loaded, equals(params));
    });

    test('load returns null when nothing was ever saved', () async {
      final store = MeshCoreRadioParamsStore();
      expect(await store.load('UNKNOWN'), isNull);
    });

    test('two distinct nodes do not collide', () async {
      final store = MeshCoreRadioParamsStore();
      const a = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 22,
      );
      const b = MeshCoreRadioParams(
        freqKhz: 915000,
        bandwidthHz: 250000,
        spreadingFactor: 11,
        codingRate: 8,
        txPowerDbm: 17,
      );

      await store.save('79426D8D', a);
      await store.save('96458BE0', b);

      expect(await store.load('79426D8D'), equals(a));
      expect(await store.load('96458BE0'), equals(b));
    });

    test('save overwrites previous value for the same node', () async {
      final store = MeshCoreRadioParamsStore();
      const first = MeshCoreRadioParams(
        freqKhz: 869525,
        bandwidthHz: 250000,
        spreadingFactor: 11,
        codingRate: 5,
        txPowerDbm: 17,
      );
      const second = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 22,
      );

      await store.save('79426D8D', first);
      await store.save('79426D8D', second);

      expect(await store.load('79426D8D'), equals(second));
    });

    test('node-key lookup is case-insensitive', () async {
      // Reasonable invariant: callers might pass node id in upper or
      // lower hex case depending on which surface produced it.
      final store = MeshCoreRadioParamsStore();
      const params = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 22,
      );

      await store.save('79426D8D', params); // upper
      expect(await store.load('79426d8d'), equals(params)); // lower
    });

    test('clear forgets the saved value', () async {
      final store = MeshCoreRadioParamsStore();
      const params = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 22,
      );

      await store.save('79426D8D', params);
      await store.clear('79426D8D');

      expect(await store.load('79426D8D'), isNull);
    });

    test('empty node key is a no-op for save and clear', () async {
      // Defensive: sheet calls _nodeKey() which can return empty if
      // SelfInfo somehow lacks a pubkey. Don't write under a global
      // empty key that would collide across nodes.
      final store = MeshCoreRadioParamsStore();
      const params = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 22,
      );

      await store.save('', params);
      expect(await store.load(''), isNull);
      await store.clear('');
    });

    test('corrupt JSON in storage returns null and self-heals', () async {
      // If a future schema change leaves stale JSON behind, loading
      // should not blow up the caller, just drop the bad entry.
      SharedPreferences.setMockInitialValues({
        'meshcore_radio_params_79426d8d': '{not_valid_json}',
      });
      final store = MeshCoreRadioParamsStore();

      final loaded = await store.load('79426D8D');
      expect(loaded, isNull);

      // After the failed load, the bad entry should be gone so the next
      // save can write fresh data.
      const fresh = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 22,
      );
      await store.save('79426D8D', fresh);
      expect(await store.load('79426D8D'), equals(fresh));
    });
  });

  group('D26 preset id persistence', () {
    test('round-trips a known preset id', () async {
      final store = MeshCoreRadioParamsStore();
      await store.savePresetId('79426D8D', 'au_default');
      expect(await store.loadPresetId('79426D8D'), equals('au_default'));
    });

    test('round-trips the Custom sentinel', () async {
      final store = MeshCoreRadioParamsStore();
      await store.savePresetId('79426D8D', 'custom');
      expect(await store.loadPresetId('79426D8D'), equals('custom'));
    });

    test('case-insensitive nodeKey hydration', () async {
      final store = MeshCoreRadioParamsStore();
      await store.savePresetId('79426D8D', 'eu_uk_narrow');
      expect(await store.loadPresetId('79426d8d'), equals('eu_uk_narrow'));
    });

    test('two different nodeKeys do not share a preset id', () async {
      final store = MeshCoreRadioParamsStore();
      await store.savePresetId('aaaaaaaa', 'us_canada');
      await store.savePresetId('bbbbbbbb', 'eu_uk_narrow');
      expect(await store.loadPresetId('aaaaaaaa'), equals('us_canada'));
      expect(await store.loadPresetId('bbbbbbbb'), equals('eu_uk_narrow'));
    });

    test('clear() removes both the params blob AND the preset id', () async {
      final store = MeshCoreRadioParamsStore();
      const params = MeshCoreRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        txPowerDbm: 14,
      );
      await store.save('79426D8D', params);
      await store.savePresetId('79426D8D', 'eu_uk_narrow');
      await store.clear('79426D8D');
      expect(await store.load('79426D8D'), isNull);
      expect(await store.loadPresetId('79426D8D'), isNull);
    });

    test('empty nodeKey is a no-op for save and load', () async {
      final store = MeshCoreRadioParamsStore();
      await store.savePresetId('', 'au_default');
      expect(await store.loadPresetId(''), isNull);
    });

    test('unsaved nodeKey returns null', () async {
      final store = MeshCoreRadioParamsStore();
      expect(await store.loadPresetId('cafebabe'), isNull);
    });
  });
}
