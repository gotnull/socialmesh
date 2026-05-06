// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D24.B — `MeshCoreContactsNotifier.mergeAdvertName` regression
// pins for the safe-merge contract.
//
// When the firmware emits `PUSH_CODE_NEW_ADVERT` (0x8A) the payload
// carries the full ContactInfo including the advertised name. The
// app parses it via `parseContact` and forwards the result to
// `mergeAdvertName`, which must:
//   - update an existing contact whose local name is empty
//   - preserve a non-empty local name (do not clobber a user-set
//     name with a fresher advert)
//   - skip silently when the advert name is empty
//   - skip silently when the public key is unknown locally
//     (caller is responsible for triggering a contacts refresh)
//   - never create placeholder contacts from advert data
//
// These tests pin each branch so a future refactor can't loosen
// the contract without an explicit test update.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

MeshCoreContact _contact({required Uint8List publicKey, String name = ''}) {
  return MeshCoreContact(
    publicKey: publicKey,
    name: name,
    type: MeshCoreAdvType.chat,
    pathLength: 0,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 6),
  );
}

Uint8List _radioBKey() {
  // Radio B's publishd full pubkey shape from the live logs:
  // 96458be0… e877e312
  final bytes = Uint8List(32);
  bytes[0] = 0x96;
  bytes[1] = 0x45;
  bytes[2] = 0x8b;
  bytes[3] = 0xe0;
  for (var i = 4; i < 28; i++) {
    bytes[i] = 0xaa;
  }
  bytes[28] = 0xe8;
  bytes[29] = 0x77;
  bytes[30] = 0xe3;
  bytes[31] = 0x12;
  return bytes;
}

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('mergeAdvertName (D24.B safe-merge contract)', () {
    test('updates an existing contact with empty local name', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(meshCoreContactsProvider.notifier);
      final radioB = _radioBKey();
      notifier.addContactLocal(_contact(publicKey: radioB, name: ''));

      final outcome = notifier.mergeAdvertName(_hex(radioB), 'WisMeshCore');

      expect(outcome, equals('ok'));
      expect(
        c.read(meshCoreContactsProvider).contacts.single.name,
        equals('WisMeshCore'),
      );
    });

    test('preserves an existing non-empty local name', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(meshCoreContactsProvider.notifier);
      final radioB = _radioBKey();
      notifier.addContactLocal(_contact(publicKey: radioB, name: 'OldName'));

      final outcome = notifier.mergeAdvertName(_hex(radioB), 'NewerName');

      expect(outcome, equals('preserved'));
      expect(
        c.read(meshCoreContactsProvider).contacts.single.name,
        equals('OldName'),
        reason:
            'A real local name must never be clobbered by an advert: '
            'newer is not always better, and users may have manually '
            'renamed a contact.',
      );
    });

    test('empty advert name is a no-op (skipped, never overwrites)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(meshCoreContactsProvider.notifier);
      final radioB = _radioBKey();
      notifier.addContactLocal(_contact(publicKey: radioB, name: 'StillHere'));

      final outcome = notifier.mergeAdvertName(_hex(radioB), '');

      expect(outcome, equals('empty_advert'));
      expect(
        c.read(meshCoreContactsProvider).contacts.single.name,
        equals('StillHere'),
      );
    });

    test('unknown public key returns no_match without creating a contact', () {
      // Hard rule from D24.B: never auto-create a placeholder
      // contact from an advert. The caller is expected to trigger
      // a `getContacts()` refresh on `'no_match'` so the firmware
      // delivers the new entry through the canonical path.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(meshCoreContactsProvider.notifier);
      final radioB = _radioBKey();
      // Note: contact list is intentionally empty.

      final outcome = notifier.mergeAdvertName(_hex(radioB), 'WisMeshCore');

      expect(outcome, equals('no_match'));
      expect(c.read(meshCoreContactsProvider).contacts, isEmpty);
    });

    test('non-64-char hex (sender prefix) is rejected as no_match', () {
      // Defensive: 6-byte sender prefixes (12 hex chars) come from
      // V3 message frames, NOT from adverts. They must NOT take
      // the heal path because partial identity isn't safe to match.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(meshCoreContactsProvider.notifier);
      final radioB = _radioBKey();
      notifier.addContactLocal(_contact(publicKey: radioB, name: ''));

      final outcome = notifier.mergeAdvertName('96458be0b1c5', 'WisMeshCore');
      expect(outcome, equals('no_match'));
      // Local entry untouched.
      expect(c.read(meshCoreContactsProvider).contacts.single.name, isEmpty);
    });

    test('case-insensitive pubkey hex match', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(meshCoreContactsProvider.notifier);
      final radioB = _radioBKey();
      notifier.addContactLocal(_contact(publicKey: radioB, name: ''));

      final upperHex = _hex(radioB).toUpperCase();
      final outcome = notifier.mergeAdvertName(upperHex, 'WisMeshCore');

      expect(outcome, equals('ok'));
      expect(
        c.read(meshCoreContactsProvider).contacts.single.name,
        equals('WisMeshCore'),
      );
    });

    test('only the matching contact is updated when multiple exist', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(meshCoreContactsProvider.notifier);
      final radioB = _radioBKey();
      final radioC = Uint8List.fromList(List.generate(32, (i) => 0x33));
      notifier.addContactLocal(_contact(publicKey: radioC, name: 'ThirdRadio'));
      notifier.addContactLocal(_contact(publicKey: radioB, name: ''));

      final outcome = notifier.mergeAdvertName(_hex(radioB), 'WisMeshCore');

      expect(outcome, equals('ok'));
      final contacts = c.read(meshCoreContactsProvider).contacts;
      expect(contacts.length, equals(2));
      // Order is name-sorted, so verify by lookup.
      final radioBEntry = contacts.firstWhere(
        (c) => c.publicKeyHex == _hex(radioB),
      );
      final radioCEntry = contacts.firstWhere(
        (c) => c.publicKeyHex == _hex(radioC),
      );
      expect(radioBEntry.name, equals('WisMeshCore'));
      expect(radioCEntry.name, equals('ThirdRadio'));
    });

    test('outcome strings are stable for log-attribution', () {
      // The 0x8A handler logs `event=contact.advert.name.update.skipped
      // reason=<outcome>` and the field log relies on these exact
      // strings. Pin them here so a casing/spelling change can't
      // silently break log analysis.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(meshCoreContactsProvider.notifier);
      final radioB = _radioBKey();
      notifier.addContactLocal(_contact(publicKey: radioB, name: 'X'));

      expect(notifier.mergeAdvertName(_hex(radioB), 'Y'), equals('preserved'));
      notifier.removeContactLocal(_hex(radioB));
      expect(notifier.mergeAdvertName(_hex(radioB), 'Y'), equals('no_match'));
      expect(
        notifier.mergeAdvertName(_hex(radioB), ''),
        equals('empty_advert'),
      );
      notifier.addContactLocal(_contact(publicKey: radioB, name: ''));
      expect(notifier.mergeAdvertName(_hex(radioB), 'Y'), equals('ok'));
    });
  });
}
