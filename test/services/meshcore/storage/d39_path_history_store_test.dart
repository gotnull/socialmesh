// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D39-A - MeshCorePathHistoryStore tests.
//
// Pinned invariants:
//   - record() persists; dedup-by-bytes touches `lastUsedAt`.
//   - LRU eviction at 20 entries per contact.
//   - Newest/last-used entries render first.
//   - base64 round-trip preserves bytes verbatim.
//   - Corrupt JSON returns empty without throwing.
//   - clear() removes the per-contact key.
//   - Key shape uses 8-char prefixes only (no full pubkey).
//   - Invalid lengths (0 or > 64) rejected.
//   - Device-scoped + contact-scoped (no cross-talk).
//   - Persisted blob carries no PSK / channel-code / full pubkey.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

Uint8List _bytes(List<int> list) => Uint8List.fromList(list);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCorePathHistoryEntry serialization', () {
    test('round-trips a populated entry', () {
      final original = MeshCorePathHistoryEntry(
        id: 'idA',
        bytes: _bytes([1, 2, 3]),
        len: 3,
        source: MeshCorePathSource.trace,
        createdAt: DateTime(2026, 5, 11, 12),
        lastUsedAt: DateTime(2026, 5, 11, 13),
        label: 'home',
        successCount: 5,
      );
      final round = MeshCorePathHistoryEntry.fromJson(original.toJson())!;
      expect(round.id, 'idA');
      expect(round.bytes, equals(_bytes([1, 2, 3])));
      expect(round.len, 3);
      expect(round.source, MeshCorePathSource.trace);
      expect(round.createdAt, DateTime(2026, 5, 11, 12));
      expect(round.lastUsedAt, DateTime(2026, 5, 11, 13));
      expect(round.label, 'home');
      expect(round.successCount, 5);
    });

    test('rejects entry with len mismatched to bytes length', () {
      final raw = {
        'id': 'idA',
        'bytes': base64Encode([1, 2, 3]),
        'len': 7,
        'source': 'trace',
        'createdAt': 0,
        'lastUsedAt': 0,
      };
      expect(MeshCorePathHistoryEntry.fromJson(raw), isNull);
    });

    test('rejects entry with empty bytes', () {
      final raw = {
        'id': 'idA',
        'bytes': '',
        'len': 0,
        'source': 'trace',
        'createdAt': 0,
        'lastUsedAt': 0,
      };
      expect(MeshCorePathHistoryEntry.fromJson(raw), isNull);
    });

    test('rejects entry with bytes longer than 64', () {
      final raw = {
        'id': 'idA',
        'bytes': base64Encode(List.filled(65, 9)),
        'len': 65,
        'source': 'trace',
        'createdAt': 0,
        'lastUsedAt': 0,
      };
      expect(MeshCorePathHistoryEntry.fromJson(raw), isNull);
    });
  });

  group('MeshCorePathHistoryStore', () {
    test('record() persists a fresh entry', () async {
      final store = MeshCorePathHistoryStore();
      final updated = await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1, 2, 3]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      expect(updated, hasLength(1));
      final loaded = await store.load('79426d8d', 'aabbccdd');
      expect(loaded.single.bytes, equals(_bytes([1, 2, 3])));
      expect(loaded.single.source, MeshCorePathSource.trace);
    });

    test('record() dedupes by exact bytes and touches lastUsedAt', () async {
      final store = MeshCorePathHistoryStore();
      final firstNow = DateTime(2026, 5, 11, 12);
      final secondNow = DateTime(2026, 5, 11, 13);
      await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1, 2, 3]),
        source: MeshCorePathSource.trace,
        now: firstNow,
      );
      final updated = await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1, 2, 3]),
        source: MeshCorePathSource.manual,
        now: secondNow,
      );
      expect(updated, hasLength(1));
      // Source must be preserved (original source describes how the
      // entry first entered the history).
      expect(updated.single.source, MeshCorePathSource.trace);
      expect(updated.single.lastUsedAt, secondNow);
    });

    test('LRU eviction at 20 entries per contact', () async {
      final store = MeshCorePathHistoryStore();
      // Insert 21 entries with strictly increasing timestamps.
      for (int i = 0; i < 21; i++) {
        await store.record(
          devicePubKeyPrefix: '79426d8d',
          contactPubKeyPrefix: 'aabbccdd',
          bytes: _bytes([i + 1]),
          source: MeshCorePathSource.trace,
          now: DateTime(2026, 5, 11, 12).add(Duration(seconds: i)),
        );
      }
      final loaded = await store.load('79426d8d', 'aabbccdd');
      expect(loaded, hasLength(20));
      // The first-inserted entry (oldest lastUsedAt) must have been
      // evicted; bytes[0] == 1 is gone.
      expect(
        loaded.where((e) => e.bytes.first == 1),
        isEmpty,
        reason: 'oldest LRU entry must be evicted past the 20 cap',
      );
      // The most recent entry (bytes[0] == 21) must be at the head.
      expect(loaded.first.bytes.first, 21);
    });

    test('entries render newest-used first', () async {
      final store = MeshCorePathHistoryStore();
      await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([2]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 13),
      );
      final loaded = await store.load('79426d8d', 'aabbccdd');
      expect(loaded.first.bytes, equals(_bytes([2])));
      expect(loaded.last.bytes, equals(_bytes([1])));
    });

    test('touch() bumps lastUsedAt on an existing entry', () async {
      final store = MeshCorePathHistoryStore();
      await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      final loaded = await store.load('79426d8d', 'aabbccdd');
      final id = loaded.single.id;
      final after = await store.touch(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        entryId: id,
        now: DateTime(2026, 5, 11, 14),
      );
      expect(after.single.lastUsedAt, DateTime(2026, 5, 11, 14));
    });

    test('delete() removes an entry', () async {
      final store = MeshCorePathHistoryStore();
      await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      final loaded = await store.load('79426d8d', 'aabbccdd');
      final id = loaded.single.id;
      final after = await store.delete(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        entryId: id,
      );
      expect(after, isEmpty);
    });

    test('invalid byte lengths are silently rejected', () async {
      final store = MeshCorePathHistoryStore();
      final empty = await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      expect(empty, isEmpty);
      final tooLong = await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: Uint8List.fromList(List.filled(65, 9)),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      expect(tooLong, isEmpty);
    });

    test('corrupt JSON returns empty without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'meshcore_path_history_79426d8d_aabbccdd': '{ not valid',
      });
      final store = MeshCorePathHistoryStore();
      final loaded = await store.load('79426d8d', 'aabbccdd');
      expect(loaded, isEmpty);
    });

    test('clear() removes the per-contact key', () async {
      final store = MeshCorePathHistoryStore();
      await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      await store.clear('79426d8d', 'aabbccdd');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey('meshcore_path_history_79426d8d_aabbccdd'),
        isFalse,
      );
    });

    test('empty prefixes are a no-op', () async {
      final store = MeshCorePathHistoryStore();
      final emptyDevice = await store.record(
        devicePubKeyPrefix: '',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      expect(emptyDevice, isEmpty);
      final emptyContact = await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: '',
        bytes: _bytes([1]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      expect(emptyContact, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final ours = prefs.getKeys().where(
        (k) => k.startsWith('meshcore_path_history_'),
      );
      expect(ours, isEmpty);
    });

    test('device + contact scoping: 4-way independence', () async {
      final store = MeshCorePathHistoryStore();
      await store.record(
        devicePubKeyPrefix: 'aaaa1111',
        contactPubKeyPrefix: 'cccc1111',
        bytes: _bytes([1]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      await store.record(
        devicePubKeyPrefix: 'aaaa1111',
        contactPubKeyPrefix: 'cccc2222',
        bytes: _bytes([2]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );
      await store.record(
        devicePubKeyPrefix: 'bbbb1111',
        contactPubKeyPrefix: 'cccc1111',
        bytes: _bytes([3]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );

      final a1 = await store.load('aaaa1111', 'cccc1111');
      final a2 = await store.load('aaaa1111', 'cccc2222');
      final b1 = await store.load('bbbb1111', 'cccc1111');

      expect(a1.single.bytes.first, 1);
      expect(a2.single.bytes.first, 2);
      expect(b1.single.bytes.first, 3);
    });

    test('key shape uses 8-char prefixes; persisted blob carries no '
        'pubkey / PSK / channel-code material', () async {
      final store = MeshCorePathHistoryStore();
      await store.record(
        devicePubKeyPrefix: '79426d8d',
        contactPubKeyPrefix: 'aabbccdd',
        bytes: _bytes([1, 2, 3, 4]),
        source: MeshCorePathSource.trace,
        now: DateTime(2026, 5, 11, 12),
      );

      final prefs = await SharedPreferences.getInstance();
      final ours = prefs
          .getKeys()
          .where((k) => k.startsWith('meshcore_path_history_'))
          .toList();
      expect(ours, hasLength(1));
      expect(ours.single, equals('meshcore_path_history_79426d8d_aabbccdd'));

      final blob = prefs.getString(ours.single)!;
      final fullPubkeyShape = RegExp(r'[0-9a-fA-F]{64}');
      final pskShape = RegExp(r'[0-9a-fA-F]{32}');
      final channelCodeShape = RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}');
      expect(fullPubkeyShape.hasMatch(blob), isFalse);
      expect(pskShape.hasMatch(blob), isFalse);
      expect(channelCodeShape.hasMatch(blob), isFalse);
      // Sanity: the bytes ARE on disk as base64.
      final decoded = jsonDecode(blob) as Map<String, dynamic>;
      final entries = decoded['entries'] as List;
      expect(entries, hasLength(1));
      expect(entries.first['bytes'], base64Encode([1, 2, 3, 4]));
    });
  });
}
