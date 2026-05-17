// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q11 pure pins: chemistry estimator + per-self-pubkey store.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_battery_chemistry.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_battery_chemistry_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('estimateMeshCoreBatteryPercent', () {
    test('non-positive voltage returns null (unknown, not 0%)', () {
      expect(estimateMeshCoreBatteryPercent(voltageMv: 0), isNull);
      expect(estimateMeshCoreBatteryPercent(voltageMv: -50), isNull);
    });

    test('LiPo: 3000 mV → 0%, 4200 mV → 100%, 3600 mV → 50%', () {
      expect(estimateMeshCoreBatteryPercent(voltageMv: 3000), 0);
      expect(estimateMeshCoreBatteryPercent(voltageMv: 4200), 100);
      expect(estimateMeshCoreBatteryPercent(voltageMv: 3600), 50);
    });

    test('auto chemistry == LiPo (firmware-default curve)', () {
      for (final mv in const [3000, 3300, 3600, 3900, 4200]) {
        final auto = estimateMeshCoreBatteryPercent(
          voltageMv: mv,
          chemistry: MeshCoreBatteryChemistry.auto,
        );
        final lipo = estimateMeshCoreBatteryPercent(
          voltageMv: mv,
          chemistry: MeshCoreBatteryChemistry.lipo,
        );
        expect(auto, lipo, reason: 'mv=$mv');
      }
    });

    test('LiFePO4 sits on a flatter curve (2.5V–3.6V)', () {
      expect(
        estimateMeshCoreBatteryPercent(
          voltageMv: 2500,
          chemistry: MeshCoreBatteryChemistry.lifepo4,
        ),
        0,
      );
      expect(
        estimateMeshCoreBatteryPercent(
          voltageMv: 3600,
          chemistry: MeshCoreBatteryChemistry.lifepo4,
        ),
        100,
      );
      // Mid-point of the LiFePO4 range, 3050 mV → 50%.
      expect(
        estimateMeshCoreBatteryPercent(
          voltageMv: 3050,
          chemistry: MeshCoreBatteryChemistry.lifepo4,
        ),
        50,
      );
    });

    test('Li-Ion (2.75V–4.2V)', () {
      expect(
        estimateMeshCoreBatteryPercent(
          voltageMv: 2750,
          chemistry: MeshCoreBatteryChemistry.liion,
        ),
        0,
      );
      expect(
        estimateMeshCoreBatteryPercent(
          voltageMv: 4200,
          chemistry: MeshCoreBatteryChemistry.liion,
        ),
        100,
      );
    });

    test('NiMH (0.9V–1.4V single-cell)', () {
      expect(
        estimateMeshCoreBatteryPercent(
          voltageMv: 900,
          chemistry: MeshCoreBatteryChemistry.nimh,
        ),
        0,
      );
      expect(
        estimateMeshCoreBatteryPercent(
          voltageMv: 1400,
          chemistry: MeshCoreBatteryChemistry.nimh,
        ),
        100,
      );
    });

    test('clamps below empty → 0 and above full → 100 for every chemistry', () {
      for (final c in MeshCoreBatteryChemistry.values) {
        final range = kMeshCoreBatteryRange[c]!;
        expect(
          estimateMeshCoreBatteryPercent(
            voltageMv: range.$1 - 100,
            chemistry: c,
          ),
          0,
          reason: '$c below empty must clamp to 0',
        );
        expect(
          estimateMeshCoreBatteryPercent(
            voltageMv: range.$2 + 100,
            chemistry: c,
          ),
          100,
          reason: '$c above full must clamp to 100',
        );
      }
    });
  });

  group('MeshCoreBatteryChemistryStore', () {
    test('empty store returns empty map', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreBatteryChemistryStore(prefs);
      expect(store.read(), isEmpty);
    });

    test('write then read returns the same overrides', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreBatteryChemistryStore(prefs);
      await store.write({
        'aabbccdd': MeshCoreBatteryChemistry.lifepo4,
        'eeff1122': MeshCoreBatteryChemistry.liion,
      });
      final loaded = store.read();
      expect(loaded['aabbccdd'], MeshCoreBatteryChemistry.lifepo4);
      expect(loaded['eeff1122'], MeshCoreBatteryChemistry.liion);
    });

    test('pubkey is normalised to lowercase on write + read', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreBatteryChemistryStore(prefs);
      await store.write({'AABBCC': MeshCoreBatteryChemistry.nimh});
      expect(store.read()['aabbcc'], MeshCoreBatteryChemistry.nimh);
    });

    test('unknown chemistry name in storage is silently dropped', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'meshcore_battery_chemistry_v1':
            '{"aabbcc":"made_up_chemistry","ddeeff":"lifepo4"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreBatteryChemistryStore(prefs);
      final loaded = store.read();
      expect(loaded, hasLength(1));
      expect(loaded['ddeeff'], MeshCoreBatteryChemistry.lifepo4);
    });

    test('malformed JSON returns empty map without throwing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'meshcore_battery_chemistry_v1': 'not json',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreBatteryChemistryStore(prefs);
      expect(store.read(), isEmpty);
    });
  });

  group('setIn / lookup pure helpers', () {
    test('setIn maps a fresh pubkey to a chemistry', () {
      final next = MeshCoreBatteryChemistryStore.setIn(
        current: const {},
        pubKeyHex: 'AABBCC',
        chemistry: MeshCoreBatteryChemistry.lifepo4,
      );
      expect(next, {'aabbcc': MeshCoreBatteryChemistry.lifepo4});
    });

    test('setIn with auto removes the persisted entry (no-op overrides '
        'should not bloat the map)', () {
      final next = MeshCoreBatteryChemistryStore.setIn(
        current: {
          'aabbcc': MeshCoreBatteryChemistry.lifepo4,
          'ddeeff': MeshCoreBatteryChemistry.liion,
        },
        pubKeyHex: 'aabbcc',
        chemistry: MeshCoreBatteryChemistry.auto,
      );
      expect(next, isNot(contains('aabbcc')));
      expect(next['ddeeff'], MeshCoreBatteryChemistry.liion);
    });

    test('setIn with auto on an absent key is a no-op (same instance)', () {
      const current = <String, MeshCoreBatteryChemistry>{};
      final next = MeshCoreBatteryChemistryStore.setIn(
        current: current,
        pubKeyHex: 'aabbcc',
        chemistry: MeshCoreBatteryChemistry.auto,
      );
      expect(identical(next, current), isTrue);
    });

    test('setIn is a no-op when the same chemistry is set twice', () {
      const current = {'aabbcc': MeshCoreBatteryChemistry.lifepo4};
      final next = MeshCoreBatteryChemistryStore.setIn(
        current: current,
        pubKeyHex: 'aabbcc',
        chemistry: MeshCoreBatteryChemistry.lifepo4,
      );
      expect(identical(next, current), isTrue);
    });

    test('lookup returns auto when no override exists', () {
      expect(
        MeshCoreBatteryChemistryStore.lookup(const {}, 'aabbcc'),
        MeshCoreBatteryChemistry.auto,
      );
    });

    test('lookup is case-insensitive', () {
      const current = {'aabbcc': MeshCoreBatteryChemistry.nimh};
      expect(
        MeshCoreBatteryChemistryStore.lookup(current, 'AABBCC'),
        MeshCoreBatteryChemistry.nimh,
      );
    });
  });
}
