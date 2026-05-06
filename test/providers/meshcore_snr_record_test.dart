// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D28 Part A - per-contact SNR badge plumbing.
//
// Verifies that `MeshCoreContactsNotifier.recordSnrFromPrefix(prefix, snr)`
// finds a contact by pubkey-prefix match and stamps the latest SNR on
// it without disturbing other contacts. Session-only: SNR is not
// persisted, so the field defaults to null on a fresh contact.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

MeshCoreContact _contact(String hexKey, {String name = 'Test'}) {
  final bytes = <int>[];
  for (var i = 0; i < hexKey.length; i += 2) {
    bytes.add(int.parse(hexKey.substring(i, i + 2), radix: 16));
  }
  return MeshCoreContact(
    publicKey: Uint8List.fromList(bytes),
    name: name,
    type: 1, // chat
    pathLength: 0,
    path: Uint8List(0),
    lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

void main() {
  group('MeshCoreContact.snrQuarter / snrDb', () {
    test('defaults to null and snrDb returns null', () {
      final c = _contact('aa' * 32);
      expect(c.snrQuarter, isNull);
      expect(c.snrDb, isNull);
    });

    test('snrDb is snrQuarter / 4.0', () {
      final c = _contact('aa' * 32).copyWith(snrQuarter: -16);
      expect(c.snrDb, -4.0);
    });

    test('copyWith clearSnrQuarter wipes the field', () {
      final c = _contact('aa' * 32).copyWith(snrQuarter: 20);
      expect(c.snrDb, 5.0);
      final cleared = c.copyWith(clearSnrQuarter: true);
      expect(cleared.snrQuarter, isNull);
      expect(cleared.snrDb, isNull);
    });
  });

  group('MeshCoreContactsNotifier.recordSnrFromPrefix', () {
    test('finds contact by 6-byte hex prefix and stamps SNR', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(meshCoreContactsProvider.notifier);

      final hexKey =
          '794265d8d011223344556677889900aabbccddeeff'
              '00' *
          6;
      final padded = hexKey.padRight(64, '0').substring(0, 64);
      notifier.addContactLocal(_contact(padded, name: 'TerryDev2'));

      // Use the first 12 hex chars (= 6 bytes) as the firmware-supplied
      // sender prefix.
      final prefix = padded.substring(0, 12);
      final matched = notifier.recordSnrFromPrefix(prefix, 20);
      expect(matched, equals(padded));

      final updated = container
          .read(meshCoreContactsProvider)
          .contacts
          .firstWhere((c) => c.publicKeyHex == padded);
      expect(updated.snrQuarter, 20);
      expect(updated.snrDb, 5.0);
    });

    test('returns null when no contact matches', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(meshCoreContactsProvider.notifier);
      notifier.addContactLocal(_contact('aa' * 32, name: 'A'));

      final matched = notifier.recordSnrFromPrefix('ff' * 6, -8);
      expect(matched, isNull);
    });

    test('case-insensitive prefix match', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(meshCoreContactsProvider.notifier);
      // Build a 64-char (32-byte) hex key. `publicKeyHex` always
      // round-trips to lowercase, so the stored contact's key is
      // lowercase regardless of construction case.
      final key = 'ABCDEF010203${'00' * 26}';
      notifier.addContactLocal(_contact(key, name: 'B'));
      final stored = container
          .read(meshCoreContactsProvider)
          .contacts
          .first
          .publicKeyHex;
      // Pass the prefix in UPPERCASE to verify the recorder lowers
      // before comparing against the lowercased stored key.
      final matched = notifier.recordSnrFromPrefix('ABCDEF010203', 4);
      expect(matched, equals(stored));
      final updated = container
          .read(meshCoreContactsProvider)
          .contacts
          .firstWhere((c) => c.publicKeyHex == stored);
      expect(updated.snrQuarter, 4);
    });

    test('does not mutate other contacts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(meshCoreContactsProvider.notifier);
      notifier.addContactLocal(_contact('11' * 32, name: 'one'));
      notifier.addContactLocal(_contact('22' * 32, name: 'two'));

      notifier.recordSnrFromPrefix('11' * 6, 12);

      final state = container.read(meshCoreContactsProvider);
      final one = state.contacts.firstWhere((c) => c.name == 'one');
      final two = state.contacts.firstWhere((c) => c.name == 'two');
      expect(one.snrQuarter, 12);
      expect(two.snrQuarter, isNull);
    });

    test('rejects empty prefix', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(meshCoreContactsProvider.notifier);
      notifier.addContactLocal(_contact('aa' * 32));
      expect(notifier.recordSnrFromPrefix('', 5), isNull);
    });

    test('overwrites previous SNR (latest wins)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(meshCoreContactsProvider.notifier);
      notifier.addContactLocal(_contact('cc' * 32));

      notifier.recordSnrFromPrefix('cc' * 6, -16);
      var c = container.read(meshCoreContactsProvider).contacts.first;
      expect(c.snrQuarter, -16);

      notifier.recordSnrFromPrefix('cc' * 6, 8);
      c = container.read(meshCoreContactsProvider).contacts.first;
      expect(c.snrQuarter, 8);
    });
  });
}
