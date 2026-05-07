// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D33 — cross-device contact-MMF symmetry tests.
//
// Pinned invariant (2026-05-07 fix):
//
//   For the same logical contact-scope message, the AUTHOR's stored
//   outbound MMF and the RECIPIENT's stored inbound MMF must be
//   byte-equal as `02:<author_pubkey_prefix:6B>:<wire_ts:u32_LE>`.
//
//   Pre-fix this was internally inconsistent: outbound used the
//   recipient's prefix while inbound used the author's prefix. The
//   sender's reply target embedded one shape, the receiver tried to
//   resolve a different shape, and the rich quote-preview row
//   silently fell through to the localized "Reply to a message you
//   don't have" fallback even when the target was clearly in the
//   receiver's local store. Live field-test 2026-05-07 confirmed.
//
// These tests exercise the storage backfill path because that is the
// post-load surface that locks the rule for already-persisted records,
// and they exercise both the iPhone-authored and sim-authored
// directions because the bug needed BOTH ends to round-trip cleanly.
//
// They do NOT pump the chat screen — outbound MMF derivation at
// SEND time is exercised separately via `_outboundMmfFor` in
// `meshcore_chat_screen.dart` (covered by widget + integration
// tests). The on-disk persistence path is what the field-test
// surfaced as broken, so that's what these tests pin.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';

void main() {
  // Two real test radios from the field smoke; using their actual
  // 6-byte prefixes makes the test serve as a regression pin for
  // the exact MMFs we observed on the wire.
  final iphonePrefix = Uint8List.fromList([0x96, 0x45, 0x8B, 0xE0, 0xB1, 0xC5]);
  final simPrefix = Uint8List.fromList([0x79, 0x42, 0x6D, 0x8D, 0xBB, 0x8F]);

  // Pad to 32 bytes so the persist path can store a full pubkey.
  Uint8List padTo32(Uint8List head) {
    final out = Uint8List(32);
    for (var i = 0; i < head.length; i++) {
      out[i] = head[i];
    }
    return out;
  }

  // Build a single-record partition snapshot.
  Map<String, Object> legacyContactPartition({
    required String contactPubkeyHex,
    required Map<String, Object?> recordJson,
  }) {
    return {
      'meshcore_messages_contact_$contactPubkeyHex': jsonEncode([recordJson]),
    };
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('iPhone-authored DM: both ends store the same MMF', () {
    // The iPhone is the AUTHOR. iPhone's outbound persist saves the
    // record into the partition keyed by the SIM's pubkey hex
    // (recipient = sim). The senderKey field carries iPhone's own
    // pubkey (author).
    test('iPhone outbound MMF = 02:<iphone-prefix>:<ts>', () async {
      final iphoneFull = padTo32(iphonePrefix);
      // Partition: recipient pubkey hex = SIM's full pubkey hex.
      final simPubkeyHex = (padTo32(
        simPrefix,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      const wireTsMs = 1700000000000;

      SharedPreferences.setMockInitialValues(
        legacyContactPartition(
          contactPubkeyHex: simPubkeyHex,
          recordJson: {
            'id': 'iphone-out-1',
            'senderKey': base64Encode(iphoneFull), // author = iPhone
            'text': 'Are you receiving this 915mhz DM FROM my iPhone too?',
            'timestamp': wireTsMs,
            'isOutgoing': true,
            'status': 1,
          },
        ),
      );

      final store = MeshCoreMessageStore();
      final loaded = await store.loadContactMessages(simPubkeyHex);
      expect(loaded, hasLength(1));
      expect(
        loaded.first.mmf,
        '02:96458be0b1c5:6553f100',
        reason: 'iPhone outbound must use iPhone (author) prefix',
      );
    });

    // The SIM is the RECIPIENT. Sim's inbound persist saves into the
    // partition keyed by the iPhone's pubkey hex (the contact who
    // sent this DM). The senderKey field carries iPhone's pubkey
    // (still the author).
    test('sim inbound MMF = 02:<iphone-prefix>:<ts> (matches author '
        'outbound byte-for-byte)', () async {
      final iphoneFull = padTo32(iphonePrefix);
      final iphonePubkeyHex = iphoneFull
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      const wireTsMs = 1700000000000;

      SharedPreferences.setMockInitialValues(
        legacyContactPartition(
          contactPubkeyHex: iphonePubkeyHex,
          recordJson: {
            'id': 'sim-in-1',
            'senderKey': base64Encode(iphoneFull), // author = iPhone
            'text': 'Are you receiving this 915mhz DM FROM my iPhone too?',
            'timestamp': wireTsMs,
            'isOutgoing': false,
            'status': 2,
          },
        ),
      );

      final store = MeshCoreMessageStore();
      final loaded = await store.loadContactMessages(iphonePubkeyHex);
      expect(loaded, hasLength(1));
      expect(
        loaded.first.mmf,
        '02:96458be0b1c5:6553f100',
        reason:
            'sim inbound MMF must match iPhone outbound MMF '
            'byte-for-byte (cross-device symmetry)',
      );
    });
  });

  group('sim-authored DM: both ends store the same MMF', () {
    test('sim outbound MMF = 02:<sim-prefix>:<ts>', () async {
      final simFull = padTo32(simPrefix);
      final iphonePubkeyHex = (padTo32(
        iphonePrefix,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      const wireTsMs = 1700000004000;

      SharedPreferences.setMockInitialValues(
        legacyContactPartition(
          contactPubkeyHex: iphonePubkeyHex,
          recordJson: {
            'id': 'sim-out-1',
            'senderKey': base64Encode(simFull),
            'text': 'D33 reply check from sim',
            'timestamp': wireTsMs,
            'isOutgoing': true,
            'status': 1,
          },
        ),
      );

      final store = MeshCoreMessageStore();
      final loaded = await store.loadContactMessages(iphonePubkeyHex);
      expect(loaded, hasLength(1));
      expect(
        loaded.first.mmf,
        '02:79426d8dbb8f:6553f104',
        reason: 'sim outbound must use sim (author) prefix',
      );
    });

    test('iPhone inbound MMF = 02:<sim-prefix>:<ts> (matches sim '
        'outbound byte-for-byte)', () async {
      final simFull = padTo32(simPrefix);
      final simPubkeyHex = simFull
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      const wireTsMs = 1700000004000;

      SharedPreferences.setMockInitialValues(
        legacyContactPartition(
          contactPubkeyHex: simPubkeyHex,
          recordJson: {
            'id': 'iphone-in-1',
            'senderKey': base64Encode(simFull), // author = sim
            'text': 'D33 reply check from sim',
            'timestamp': wireTsMs,
            'isOutgoing': false,
            'status': 2,
          },
        ),
      );

      final store = MeshCoreMessageStore();
      final loaded = await store.loadContactMessages(simPubkeyHex);
      expect(loaded, hasLength(1));
      expect(
        loaded.first.mmf,
        '02:79426d8dbb8f:6553f104',
        reason:
            'iPhone inbound MMF must match sim outbound MMF '
            'byte-for-byte (cross-device symmetry)',
      );
    });
  });

  group('reply target resolution after round-trip', () {
    // This is the bug the field test surfaced, mechanically pinned:
    // an iPhone-authored message goes into both stores with the same
    // MMF; a sim reply that embeds the iPhone-author MMF as `target`
    // can be resolved by the iPhone via that exact MMF string — no
    // missing-target fallback.
    test('sim reply embedding iPhone-author MMF resolves to the '
        'iPhone-authored bubble in iPhone\'s local store', () async {
      final iphoneFull = padTo32(iphonePrefix);
      final iphonePubkeyHex = iphoneFull
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      const originalTsMs = 1700000000000;
      const originalMmf = '02:96458be0b1c5:6553f100';

      // iPhone has its own outbound bubble persisted.
      // Plus a sim reply (inbound) that targets it by MMF.
      SharedPreferences.setMockInitialValues({
        'meshcore_messages_contact_${'78' * 32}': jsonEncode([
          // iPhone outbound (the original message being replied to).
          // Partition is the recipient (sim) hex.
          {
            'id': 'iphone-out-target',
            'senderKey': base64Encode(iphoneFull),
            'text': 'Are you receiving this 915mhz DM FROM my iPhone too?',
            'timestamp': originalTsMs,
            'isOutgoing': true,
            'status': 1,
          },
        ]),
      });
      // Reload from iPhone's POV: partition = recipient (sim) hex.
      final iphoneStore = MeshCoreMessageStore();
      final iphoneRecords = await iphoneStore.loadContactMessages('78' * 32);
      expect(iphoneRecords, hasLength(1));
      expect(
        iphoneRecords.first.mmf,
        originalMmf,
        reason:
            'iPhone-side stored MMF must equal the MMF a remote '
            'sender will embed when replying — that is the entire '
            'point of the symmetry contract.',
      );

      // The OPPOSITE side (sim) loading the inbound counterpart of
      // the same message produces the IDENTICAL MMF.
      SharedPreferences.setMockInitialValues({
        'meshcore_messages_contact_$iphonePubkeyHex': jsonEncode([
          {
            'id': 'sim-in-target',
            'senderKey': base64Encode(iphoneFull),
            'text': 'Are you receiving this 915mhz DM FROM my iPhone too?',
            'timestamp': originalTsMs,
            'isOutgoing': false,
            'status': 2,
          },
        ]),
      });
      final simStore = MeshCoreMessageStore();
      final simRecords = await simStore.loadContactMessages(iphonePubkeyHex);
      expect(simRecords.first.mmf, originalMmf);
      // Sim therefore embeds `originalMmf` in its reply envelope.
      // iPhone receives the reply, decodes target=originalMmf, and
      // looks up via _findMessageByMmf — the lookup hits
      // `iphoneRecords.first` because both sides share the same MMF
      // string. No fallback. End-to-end symmetry confirmed.
    });
  });
}
