// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q8 pure store + helper pins for the per-contact block list.
// Notifier wiring is covered separately in
// `test/providers/meshcore_contact_block_provider_test.dart`.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_contact_block_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreContactBlockStore read/write round-trip', () {
    test('read returns empty when no key is persisted', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreContactBlockStore(prefs);
      expect(store.read(), isEmpty);
    });

    test('write then read returns the same set', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreContactBlockStore(prefs);
      await store.write({'AABBCCDD', 'EEFF1122'});
      expect(store.read(), {'aabbccdd', 'eeff1122'});
    });

    test('pubkey hex is normalised to lowercase on read', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'meshcore_blocked_contacts_v1': <String>[
          'AABBCCDD',
          'eeff1122',
          'AbCdEf00',
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreContactBlockStore(prefs);
      expect(store.read(), {'aabbccdd', 'eeff1122', 'abcdef00'});
    });

    test('write sorts the stored list deterministically', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreContactBlockStore(prefs);
      await store.write({'eeff1122', 'aabbccdd', 'ccddeeff'});
      final raw = prefs.getStringList('meshcore_blocked_contacts_v1');
      expect(raw, ['aabbccdd', 'ccddeeff', 'eeff1122']);
    });

    test('write deduplicates entries that differ only in case', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreContactBlockStore(prefs);
      await store.write({'AABBCC', 'aabbcc', 'AaBbCc'});
      expect(store.read(), {'aabbcc'});
    });
  });

  group('blockIn / unblockIn pure helpers', () {
    test('blockIn adds a new entry', () {
      final next = MeshCoreContactBlockStore.blockIn({'aaaa'}, 'BBBB');
      expect(next, {'aaaa', 'bbbb'});
    });

    test(
      'blockIn is a no-op when the key is already present (case-insensitive)',
      () {
        const current = {'aaaa'};
        final next = MeshCoreContactBlockStore.blockIn(current, 'AAAA');
        expect(identical(next, current), isTrue);
      },
    );

    test('unblockIn removes an existing entry', () {
      final next = MeshCoreContactBlockStore.unblockIn({
        'aaaa',
        'bbbb',
      }, 'BBBB');
      expect(next, {'aaaa'});
    });

    test('unblockIn is a no-op when the key is absent', () {
      const current = {'aaaa'};
      final next = MeshCoreContactBlockStore.unblockIn(current, 'BBBB');
      expect(identical(next, current), isTrue);
    });

    test('blockIn normalises the input to lowercase', () {
      final next = MeshCoreContactBlockStore.blockIn(<String>{}, 'AABBCC');
      expect(next, {'aabbcc'});
    });
  });
}
