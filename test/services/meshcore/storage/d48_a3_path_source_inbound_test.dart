// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A3: `MeshCorePathSource.inbound` round-trip pins.
//
// Pinned invariants:
//   - The `inbound` value serializes to `'inbound'` via the
//     `wire` extension.
//   - `fromWire('inbound')` parses back to the enum value.
//   - An entry recorded with `source: inbound` round-trips
//     through `store.record` -> SharedPreferences -> JSON parse.
//   - A legacy record without the new field still parses as
//     `trace` (existing default; not regressed by adding `inbound`).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

const _device = 'aabbccdd';
const _contact = '11223344';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MeshCorePathHistoryStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = MeshCorePathHistoryStore();
  });

  group('MeshCorePathSource.inbound - D48-A3', () {
    test('wire serializes to "inbound"', () {
      expect(MeshCorePathSource.inbound.wire, equals('inbound'));
    });

    test('fromWire parses "inbound" back to the enum', () {
      expect(
        MeshCorePathSourceWire.fromWire('inbound'),
        equals(MeshCorePathSource.inbound),
      );
    });

    test('fromWire defaults unknown values to trace (no regression)', () {
      expect(
        MeshCorePathSourceWire.fromWire('unknown_future_value'),
        equals(MeshCorePathSource.trace),
      );
      expect(
        MeshCorePathSourceWire.fromWire(null),
        equals(MeshCorePathSource.trace),
      );
    });

    test(
      'entry recorded with source=inbound round-trips through SharedPreferences',
      () async {
        final bytes = Uint8List.fromList([0x10, 0x20, 0x30]);
        await store.record(
          devicePubKeyPrefix: _device,
          contactPubKeyPrefix: _contact,
          bytes: bytes,
          source: MeshCorePathSource.inbound,
          now: DateTime.utc(2026, 5, 14),
        );

        final reloaded = await store.load(_device, _contact);
        expect(reloaded, hasLength(1));
        expect(reloaded.single.source, equals(MeshCorePathSource.inbound));
        expect(reloaded.single.bytes, equals(bytes));
      },
    );
  });
}
