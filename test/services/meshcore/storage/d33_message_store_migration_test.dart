// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D33 — MeshCoreMessageStore migration tests.
//
// Pins the storage migration invariants the developer locked in for
// Phase 2:
//
//   - Pre-D33 JSON (no `mmf` / `replyToMmf` keys) loads without
//     exception.
//   - Post-D33 round-trip preserves both fields.
//   - MMF backfill on load is deterministic + idempotent.
//   - MMF backfill is conservative: outbound contact records that
//     pre-date the D33 partition-by-contact-pubkey shape still fall
//     through to `mmf = null` rather than inventing one.
//   - Malformed legacy entries are skipped with a safe log; the rest
//     of the partition stays readable.
//   - Saves preserve unknown fields by NOT touching them in the
//     ToJson surface.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // -------------------------------------------------------------------
  // Pre-D33 JSON shapes (no mmf / replyToMmf fields)
  // -------------------------------------------------------------------

  group('legacy JSON load (pre-D33 records)', () {
    test('channel record without mmf/replyToMmf loads cleanly', () async {
      const partition = 0;
      final legacy = [
        {
          'id': 'legacy-channel-1',
          'senderKey': base64Encode(Uint8List(0)),
          'text': 'pre-D33 channel msg',
          'timestamp': 1700000000000, // ms epoch
          'isOutgoing': false,
          'status': 2, // delivered
          'pathLength': 0,
          'isChannelMessage': true,
          'channelIndex': partition,
          // no mmf, no replyToMmf
        },
      ];

      SharedPreferences.setMockInitialValues({
        'meshcore_messages_channel_$partition': jsonEncode(legacy),
      });

      final store = MeshCoreMessageStore();
      final loaded = await store.loadChannelMessages(partition);
      expect(loaded, hasLength(1));
      // replyToMmf stays null on legacy records.
      expect(loaded.first.replyToMmf, isNull);
      // mmf was deterministically backfilled from channelIndex+ts.
      expect(loaded.first.mmf, '01:00:6553f100');
    });

    test('inbound contact record without mmf/replyToMmf gets MMF '
        'backfilled from senderKey + timestamp', () async {
      // 32-byte senderKey starting with 79 42 6d 8d b8 fd...
      final sender = Uint8List.fromList([
        0x79,
        0x42,
        0x6D,
        0x8D,
        0xB8,
        0xFD,
        ...List.filled(26, 0x00),
      ]);
      final partition = sender
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final legacy = [
        {
          'id': 'legacy-contact-1',
          'senderKey': base64Encode(sender),
          'text': 'pre-D33 inbound DM',
          'timestamp': 1700000000000,
          'isOutgoing': false,
          'status': 2,
        },
      ];
      SharedPreferences.setMockInitialValues({
        'meshcore_messages_contact_$partition': jsonEncode(legacy),
      });

      final store = MeshCoreMessageStore();
      final loaded = await store.loadContactMessages(partition);
      expect(loaded, hasLength(1));
      expect(loaded.first.mmf, '02:79426d8db8fd:6553f100');
      expect(loaded.first.replyToMmf, isNull);
    });

    test('outbound contact record uses partition-key prefix for MMF', () async {
      // Outbound: senderKey is the SELF's, not the recipient's.
      // The MMF must be derived from the partition (recipient
      // pubkey hex).
      final partition =
          '79426d8db8fd'
          '${'00' * 26}';
      final legacy = [
        {
          'id': 'legacy-contact-out-1',
          'senderKey': base64Encode(Uint8List(0)), // self / unknown
          'text': 'pre-D33 outbound DM',
          'timestamp': 1700000000000,
          'isOutgoing': true,
          'status': 1, // sent
        },
      ];
      SharedPreferences.setMockInitialValues({
        'meshcore_messages_contact_$partition': jsonEncode(legacy),
      });

      final store = MeshCoreMessageStore();
      final loaded = await store.loadContactMessages(partition);
      expect(loaded, hasLength(1));
      expect(
        loaded.first.mmf,
        '02:79426d8db8fd:6553f100',
        reason:
            'outbound MMF must use the recipient prefix '
            '(=partition key) so both ends agree',
      );
    });

    test(
      'inbound contact record with empty senderKey stays mmf = null',
      () async {
        final partition = 'a' * 64;
        final legacy = [
          {
            'id': 'legacy-bad',
            'senderKey': base64Encode(Uint8List(0)),
            'text': 'no sender',
            'timestamp': 1700000000000,
            'isOutgoing': false,
            'status': 2,
          },
        ];
        SharedPreferences.setMockInitialValues({
          'meshcore_messages_contact_$partition': jsonEncode(legacy),
        });

        final store = MeshCoreMessageStore();
        final loaded = await store.loadContactMessages(partition);
        expect(loaded, hasLength(1));
        expect(
          loaded.first.mmf,
          isNull,
          reason: 'no recoverable peer prefix => mmf stays null',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Backfill is idempotent
  // -------------------------------------------------------------------

  group('backfill idempotency', () {
    test('records with existing mmf are not mutated', () async {
      const partition = 1;
      final preLoaded = [
        {
          'id': 'has-mmf',
          'senderKey': base64Encode(Uint8List(0)),
          'text': 'D33 record',
          'timestamp': 1700000000000,
          'isOutgoing': false,
          'status': 2,
          'isChannelMessage': true,
          'channelIndex': partition,
          // existing MMF that does NOT match what backfill would
          // compute — the load path must NOT overwrite it.
          'mmf': 'ff:ff:ffffffff',
          'replyToMmf': null,
        },
      ];
      SharedPreferences.setMockInitialValues({
        'meshcore_messages_channel_$partition': jsonEncode(preLoaded),
      });

      final store = MeshCoreMessageStore();
      final loaded = await store.loadChannelMessages(partition);
      expect(loaded.first.mmf, 'ff:ff:ffffffff');
    });

    test(
      'reloading the same partition twice produces identical MMFs',
      () async {
        const partition = 2;
        final legacy = [
          {
            'id': 'legacy-2',
            'senderKey': base64Encode(Uint8List(0)),
            'text': 'twice',
            'timestamp': 1700000000000,
            'isOutgoing': false,
            'status': 2,
            'isChannelMessage': true,
            'channelIndex': partition,
          },
        ];
        SharedPreferences.setMockInitialValues({
          'meshcore_messages_channel_$partition': jsonEncode(legacy),
        });

        final store = MeshCoreMessageStore();
        final first = await store.loadChannelMessages(partition);
        final second = await store.loadChannelMessages(partition);
        expect(first.first.mmf, second.first.mmf);
      },
    );
  });

  // -------------------------------------------------------------------
  // Round-trip
  // -------------------------------------------------------------------

  group('post-D33 JSON round-trip', () {
    test('mmf + replyToMmf survive save → load', () async {
      const partition = 3;
      final store = MeshCoreMessageStore();
      await store.init();
      final msg = MeshCoreStoredMessage(
        id: 'd33-1',
        senderKey: Uint8List.fromList(List.generate(32, (i) => i)),
        text: 'reply body',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        isOutgoing: false,
        status: MeshCoreMessageStatus.delivered,
        isChannelMessage: true,
        channelIndex: partition,
        mmf: '01:03:6553f100',
        replyToMmf: '01:03:65560000',
      );
      await store.addChannelMessage(partition, msg);

      final loaded = await store.loadChannelMessages(partition);
      expect(loaded.first.mmf, '01:03:6553f100');
      expect(loaded.first.replyToMmf, '01:03:65560000');
    });

    test('toJson includes mmf and replyToMmf keys explicitly', () {
      final m = MeshCoreStoredMessage(
        id: 'x',
        senderKey: Uint8List(0),
        text: 'x',
        timestamp: DateTime(2026, 5, 7),
        isOutgoing: false,
        mmf: '01:00:11111111',
        replyToMmf: '01:00:22222222',
      );
      final json = m.toJson();
      expect(json['mmf'], '01:00:11111111');
      expect(json['replyToMmf'], '01:00:22222222');
    });

    test('legacy fromJson tolerates missing mmf/replyToMmf', () {
      final m = MeshCoreStoredMessage.fromJson({
        'id': 'x',
        'senderKey': base64Encode(Uint8List(0)),
        'text': 'x',
        'timestamp': 0,
        'isOutgoing': false,
        'status': 2,
      });
      expect(m.mmf, isNull);
      expect(m.replyToMmf, isNull);
    });

    test('copyWith preserves mmf/replyToMmf when not overridden', () {
      final m = MeshCoreStoredMessage(
        id: 'x',
        senderKey: Uint8List(0),
        text: 'x',
        timestamp: DateTime(2026, 5, 7),
        isOutgoing: false,
        mmf: '01:00:11111111',
        replyToMmf: '01:00:22222222',
      );
      final c = m.copyWith();
      expect(c.mmf, '01:00:11111111');
      expect(c.replyToMmf, '01:00:22222222');
    });
  });

  // -------------------------------------------------------------------
  // Malformed legacy entries
  // -------------------------------------------------------------------

  group('malformed legacy entries', () {
    test('entry that fails fromJson is skipped; rest of partition stays '
        'readable', () async {
      const partition = 4;
      // Mix one good record with one missing required `id` field.
      final partitionJson = [
        {
          'id': 'good-1',
          'senderKey': base64Encode(Uint8List(0)),
          'text': 'ok',
          'timestamp': 1700000000000,
          'isOutgoing': false,
          'status': 2,
          'isChannelMessage': true,
          'channelIndex': partition,
        },
        {
          // missing required 'id' → fromJson throws
          'senderKey': base64Encode(Uint8List(0)),
          'text': 'corrupt',
          'timestamp': 1700000000000,
          'isOutgoing': false,
          'status': 2,
        },
        {
          'id': 'good-2',
          'senderKey': base64Encode(Uint8List(0)),
          'text': 'still ok',
          'timestamp': 1700000000000,
          'isOutgoing': false,
          'status': 2,
          'isChannelMessage': true,
          'channelIndex': partition,
        },
      ];
      SharedPreferences.setMockInitialValues({
        'meshcore_messages_channel_$partition': jsonEncode(partitionJson),
      });

      final store = MeshCoreMessageStore();
      final loaded = await store.loadChannelMessages(partition);
      expect(loaded, hasLength(2));
      expect(loaded.map((m) => m.id), equals(['good-1', 'good-2']));
    });

    test('non-object entries are skipped, others kept', () async {
      const partition = 5;
      final partitionJson = [
        'this is not a record',
        {
          'id': 'g1',
          'senderKey': base64Encode(Uint8List(0)),
          'text': 'ok',
          'timestamp': 1700000000000,
          'isOutgoing': false,
          'status': 2,
          'isChannelMessage': true,
          'channelIndex': partition,
        },
      ];
      SharedPreferences.setMockInitialValues({
        'meshcore_messages_channel_$partition': jsonEncode(partitionJson),
      });

      final store = MeshCoreMessageStore();
      final loaded = await store.loadChannelMessages(partition);
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'g1');
    });
  });
}
