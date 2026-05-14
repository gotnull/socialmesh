// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A1: `MeshCorePathHistoryStore.recordPathSuccess` /
// `recordPathFailure` + schema round-trip pins.
//
// Pinned invariants:
//   - recordPathSuccess bumps successCount + writes new weight +
//     touches lastUsedAt.
//   - recordPathSuccess on unknown bytes is a no-op.
//   - recordPathFailure bumps failureCount + writes new weight
//     (positive).
//   - recordPathFailure with new weight ≤ 0 REMOVES the entry from
//     the history.
//   - recordPathFailure on unknown bytes is a no-op.
//   - JSON round-trip preserves failureCount + routeWeight.
//   - Legacy rows (pre-D48-A1) load with default 0 / default-weight
//     for the new fields.
//   - Empty / blank pubkey prefixes are no-ops.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

const _device = 'aabbccdd';
const _contact = '11223344';

MeshCorePathHistoryEntry _entry({
  required String id,
  required List<int> bytes,
  DateTime? lastUsedAt,
  int successCount = 0,
  int failureCount = 0,
  double routeWeight = 3.0,
}) {
  final now = DateTime.utc(2026, 5, 14);
  return MeshCorePathHistoryEntry(
    id: id,
    bytes: Uint8List.fromList(bytes),
    len: bytes.length,
    source: MeshCorePathSource.trace,
    createdAt: lastUsedAt ?? now,
    lastUsedAt: lastUsedAt ?? now,
    successCount: successCount,
    failureCount: failureCount,
    routeWeight: routeWeight,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MeshCorePathHistoryStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = MeshCorePathHistoryStore();
  });

  group('MeshCorePathHistoryEntry schema - D48-A1', () {
    test('failureCount + routeWeight default to 0 + default-weight', () {
      final e = MeshCorePathHistoryEntry(
        id: 'a',
        bytes: Uint8List.fromList([0x01]),
        len: 1,
        source: MeshCorePathSource.trace,
        createdAt: DateTime.utc(2026, 5, 14),
        lastUsedAt: DateTime.utc(2026, 5, 14),
      );
      expect(e.failureCount, 0);
      expect(e.routeWeight, kMeshCorePathHistoryDefaultRouteWeight);
    });

    test('JSON round-trip preserves failureCount + routeWeight', () {
      final original = _entry(
        id: 'a',
        bytes: [0x10, 0x20, 0x30],
        successCount: 7,
        failureCount: 2,
        routeWeight: 4.25,
      );
      final json = original.toJson();
      final parsed = MeshCorePathHistoryEntry.fromJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.successCount, 7);
      expect(parsed.failureCount, 2);
      expect(parsed.routeWeight, closeTo(4.25, 1e-9));
    });

    test(
      'legacy rows (no failureCount, no routeWeight) load with defaults',
      () {
        // Mimics a pre-D48-A1 on-disk record.
        final legacy = <String, Object?>{
          'id': 'legacy',
          'bytes': 'AQI=', // base64 of [0x01, 0x02]
          'len': 2,
          'source': 'trace',
          'createdAt': DateTime.utc(2026, 5, 14).millisecondsSinceEpoch,
          'lastUsedAt': DateTime.utc(2026, 5, 14).millisecondsSinceEpoch,
          'label': null,
          'successCount': 3,
        };
        final parsed = MeshCorePathHistoryEntry.fromJson(legacy);
        expect(parsed, isNotNull);
        expect(parsed!.successCount, 3);
        expect(parsed.failureCount, 0);
        expect(parsed.routeWeight, kMeshCorePathHistoryDefaultRouteWeight);
      },
    );
  });

  group('recordPathSuccess - D48-A1', () {
    test('bumps successCount, writes new weight, touches lastUsedAt', () async {
      await store.save(_device, _contact, [
        _entry(
          id: 'a',
          bytes: [0x01, 0x02],
          lastUsedAt: DateTime.utc(2026, 5, 10),
          successCount: 2,
          routeWeight: 3.0,
        ),
      ]);

      final now = DateTime.utc(2026, 5, 14, 10);
      final result = await store.recordPathSuccess(
        devicePubKeyPrefix: _device,
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0x01, 0x02]),
        newWeight: 3.5,
        now: now,
      );
      expect(result, hasLength(1));
      final updated = result.single;
      expect(updated.successCount, 3);
      expect(updated.routeWeight, closeTo(3.5, 1e-9));
      expect(updated.lastUsedAt, now);
    });

    test('unknown bytes is a no-op (existing entries unchanged)', () async {
      final existing = _entry(
        id: 'a',
        bytes: [0x01],
        successCount: 1,
        routeWeight: 3.0,
      );
      await store.save(_device, _contact, [existing]);

      final result = await store.recordPathSuccess(
        devicePubKeyPrefix: _device,
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0xFF]), // not in history
        newWeight: 99.0,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(result, hasLength(1));
      expect(result.single.successCount, 1);
      expect(result.single.routeWeight, closeTo(3.0, 1e-9));
    });

    test('empty prefix is a no-op', () async {
      final result = await store.recordPathSuccess(
        devicePubKeyPrefix: '',
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0x01]),
        newWeight: 1.0,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(result, isEmpty);
    });
  });

  group('recordPathFailure - D48-A1', () {
    test(
      'bumps failureCount + writes positive new weight (no eviction)',
      () async {
        await store.save(_device, _contact, [
          _entry(
            id: 'a',
            bytes: [0x01],
            successCount: 1,
            failureCount: 0,
            routeWeight: 3.0,
          ),
        ]);

        final result = await store.recordPathFailure(
          devicePubKeyPrefix: _device,
          contactPubKeyPrefix: _contact,
          pathBytes: Uint8List.fromList([0x01]),
          newWeight: 2.8,
        );
        expect(result, hasLength(1));
        expect(result.single.failureCount, 1);
        expect(result.single.routeWeight, closeTo(2.8, 1e-9));
      },
    );

    test('new weight ≤ 0 REMOVES the entry from history', () async {
      await store.save(_device, _contact, [
        _entry(id: 'a', bytes: [0x01], routeWeight: 0.1),
        _entry(id: 'b', bytes: [0x02], routeWeight: 5.0),
      ]);

      final result = await store.recordPathFailure(
        devicePubKeyPrefix: _device,
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0x01]),
        newWeight: -0.1,
      );
      expect(result, hasLength(1));
      expect(result.single.id, 'b');
    });

    test('exactly zero new weight is treated as eviction', () async {
      await store.save(_device, _contact, [
        _entry(id: 'a', bytes: [0x01], routeWeight: 0.2),
      ]);
      final result = await store.recordPathFailure(
        devicePubKeyPrefix: _device,
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0x01]),
        newWeight: 0.0,
      );
      expect(result, isEmpty);
    });

    test('unknown bytes is a no-op', () async {
      final existing = _entry(
        id: 'a',
        bytes: [0x01],
        failureCount: 0,
        routeWeight: 3.0,
      );
      await store.save(_device, _contact, [existing]);

      final result = await store.recordPathFailure(
        devicePubKeyPrefix: _device,
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0xFF]),
        newWeight: -5.0,
      );
      expect(result, hasLength(1));
      expect(result.single.failureCount, 0);
      expect(result.single.routeWeight, closeTo(3.0, 1e-9));
    });

    test('empty prefix is a no-op', () async {
      final result = await store.recordPathFailure(
        devicePubKeyPrefix: '',
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0x01]),
        newWeight: 1.0,
      );
      expect(result, isEmpty);
    });
  });

  group('weight updates and reload integrity - D48-A1', () {
    test('record then reload via load() preserves all new fields', () async {
      await store.save(_device, _contact, [
        _entry(
          id: 'a',
          bytes: [0x01, 0x02, 0x03],
          successCount: 0,
          failureCount: 0,
          routeWeight: 3.0,
        ),
      ]);

      await store.recordPathSuccess(
        devicePubKeyPrefix: _device,
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0x01, 0x02, 0x03]),
        newWeight: 3.5,
        now: DateTime.utc(2026, 5, 14),
      );
      await store.recordPathFailure(
        devicePubKeyPrefix: _device,
        contactPubKeyPrefix: _contact,
        pathBytes: Uint8List.fromList([0x01, 0x02, 0x03]),
        newWeight: 3.3,
      );

      final reloaded = await store.load(_device, _contact);
      expect(reloaded, hasLength(1));
      expect(reloaded.single.successCount, 1);
      expect(reloaded.single.failureCount, 1);
      expect(reloaded.single.routeWeight, closeTo(3.3, 1e-9));
    });
  });
}
