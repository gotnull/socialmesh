// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Tests for MeshCoreNodeNameStore.
//
// Validates D13 client-side persistence of the node name. The pre-D13
// bug: cold-start before SELF_INFO loads (and any post-disconnect
// window) showed "Not set" because nothing on the client remembered
// the last-applied name. Store keys on lower-case node id so two
// physically distinct radios never overwrite each other.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_node_name_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreNodeNameStore', () {
    test('save then load round-trips for a single node', () async {
      final store = MeshCoreNodeNameStore();
      await store.save('79426D8D', 'TerryDev');
      expect(await store.load('79426D8D'), equals('TerryDev'));
    });

    test('load returns null when nothing was ever saved', () async {
      final store = MeshCoreNodeNameStore();
      expect(await store.load('UNKNOWN'), isNull);
    });

    test('two distinct nodes do not collide', () async {
      final store = MeshCoreNodeNameStore();
      await store.save('79426D8D', 'TerryDev');
      await store.save('96458BE0', 'GarageRadio');

      expect(await store.load('79426D8D'), equals('TerryDev'));
      expect(await store.load('96458BE0'), equals('GarageRadio'));
    });

    test('save overwrites previous value for the same node', () async {
      final store = MeshCoreNodeNameStore();
      await store.save('79426D8D', 'OldName');
      await store.save('79426D8D', 'NewName');
      expect(await store.load('79426D8D'), equals('NewName'));
    });

    test('node-key lookup is case-insensitive', () async {
      // Reasonable invariant: callers might pass node id in upper or
      // lower hex case depending on which surface produced it.
      final store = MeshCoreNodeNameStore();
      await store.save('79426D8D', 'TerryDev'); // upper
      expect(await store.load('79426d8d'), equals('TerryDev')); // lower
    });

    test('clear forgets the saved value', () async {
      final store = MeshCoreNodeNameStore();
      await store.save('79426D8D', 'TerryDev');
      await store.clear('79426D8D');
      expect(await store.load('79426D8D'), isNull);
    });

    test('empty node key is a no-op for save, load, and clear', () async {
      // Defensive: if the coordinator hasn't surfaced a node id yet
      // (BLE handshake mid-flight) we must NOT persist under an empty
      // key that would collide across nodes.
      final store = MeshCoreNodeNameStore();
      await store.save('', 'Foo');
      expect(await store.load(''), isNull);
      await store.clear('');
    });

    test('empty name is a no-op for save', () async {
      // Don't let an in-flight clear (empty controller text) overwrite
      // a perfectly good cached value. The settings sheet's _setNodeName
      // already returns early on empty text, but defend at the store
      // layer too so future callers can't regress the invariant.
      final store = MeshCoreNodeNameStore();
      await store.save('79426D8D', 'TerryDev');
      await store.save('79426D8D', '');
      expect(await store.load('79426D8D'), equals('TerryDev'));
    });

    test('key namespace does not collide with radio params store', () async {
      // Both stores are SharedPreferences-backed and keyed by node id.
      // They MUST use distinct prefixes so a radio-params save does not
      // appear as a node name (or vice versa).
      SharedPreferences.setMockInitialValues({
        // What the radio store would write for the same node:
        'meshcore_radio_params_79426d8d':
            '{"freqKhz":869618,"bandwidthHz":62500,'
            '"spreadingFactor":8,"codingRate":5,"txPowerDbm":22}',
      });
      final store = MeshCoreNodeNameStore();
      // Node-name store must not see anything for that node.
      expect(await store.load('79426D8D'), isNull);

      await store.save('79426D8D', 'TerryDev');
      // Now both keys coexist without overwriting each other.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('meshcore_node_name_79426d8d'),
        equals('TerryDev'),
      );
      expect(
        prefs.getString('meshcore_radio_params_79426d8d'),
        isNotNull,
        reason: 'radio params entry must be untouched',
      );
    });
  });
}
