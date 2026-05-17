// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q5 ring-buffer + redaction-helper pins for the BLE debug log
// surface. The store is pure (no Riverpod, no widgets) so the tests
// can exercise the full append / clear / pause / capacity contract
// without a widget tester.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/diagnostics/meshcore_ble_debug_log_store.dart';

void main() {
  group('MeshCoreBleDebugLogStore append + capacity', () {
    test('append records an entry with the supplied severity + category', () {
      final store = MeshCoreBleDebugLogStore();
      store.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message: 'connect start',
      );
      final snap = store.snapshot();
      expect(snap, hasLength(1));
      expect(snap.first.severity, MeshCoreBleDebugLogSeverity.info);
      expect(snap.first.category, MeshCoreBleDebugLogCategory.connect);
      expect(snap.first.message, 'connect start');
    });

    test('capacity cap evicts the oldest entry FIFO', () {
      final store = MeshCoreBleDebugLogStore();
      for (var i = 0; i < kMeshCoreBleDebugLogCapacity + 5; i++) {
        store.append(
          severity: MeshCoreBleDebugLogSeverity.info,
          category: MeshCoreBleDebugLogCategory.connect,
          message: 'event $i',
        );
      }
      final snap = store.snapshot();
      expect(snap, hasLength(kMeshCoreBleDebugLogCapacity));
      expect(snap.first.message, 'event 5');
      expect(snap.last.message, 'event ${kMeshCoreBleDebugLogCapacity + 4}');
    });

    test('append timestamp defaults to DateTime.now()', () {
      final store = MeshCoreBleDebugLogStore();
      final before = DateTime.now();
      store.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.scan,
        message: 'scan start',
      );
      final after = DateTime.now();
      final entry = store.snapshot().first;
      expect(
        entry.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        entry.timestamp.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('explicit timestamp is respected', () {
      final store = MeshCoreBleDebugLogStore();
      final fixed = DateTime.utc(2026, 5, 17, 12, 0, 0);
      store.append(
        severity: MeshCoreBleDebugLogSeverity.warn,
        category: MeshCoreBleDebugLogCategory.discover,
        message: 'service missing',
        timestamp: fixed,
      );
      expect(store.snapshot().first.timestamp, fixed);
    });
  });

  group('MeshCoreBleDebugLogStore pause / resume / clear', () {
    test('pause drops new appends until resume', () {
      final store = MeshCoreBleDebugLogStore();
      store.pause();
      expect(store.isPaused, isTrue);
      store.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message: 'dropped while paused',
      );
      expect(store.snapshot(), isEmpty);
      store.resume();
      expect(store.isPaused, isFalse);
      store.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message: 'after resume',
      );
      expect(store.snapshot(), hasLength(1));
      expect(store.snapshot().first.message, 'after resume');
    });

    test('pause is idempotent and preserves the existing buffer', () {
      final store = MeshCoreBleDebugLogStore();
      store.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message: 'a',
      );
      store.pause();
      store.pause();
      expect(store.snapshot(), hasLength(1));
      expect(store.isPaused, isTrue);
    });

    test('clear empties the buffer but leaves pause state untouched', () {
      final store = MeshCoreBleDebugLogStore();
      store.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message: 'a',
      );
      store.pause();
      store.clear();
      expect(store.snapshot(), isEmpty);
      expect(store.isPaused, isTrue);
    });

    test('clear on an empty buffer is a no-op', () {
      final store = MeshCoreBleDebugLogStore();
      store.clear();
      expect(store.snapshot(), isEmpty);
    });
  });

  group('MeshCoreBleDebugLogStore stream', () {
    test('stream emits a snapshot on each append', () async {
      final store = MeshCoreBleDebugLogStore();
      final emissions = <int>[];
      final sub = store.stream.listen((s) => emissions.add(s.length));
      store.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message: 'a',
      );
      store.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message: 'b',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissions, [1, 2]);
      await sub.cancel();
      await store.dispose();
    });

    test(
      'stream fires on clear so the UI can re-render the empty state',
      () async {
        final store = MeshCoreBleDebugLogStore();
        store.append(
          severity: MeshCoreBleDebugLogSeverity.info,
          category: MeshCoreBleDebugLogCategory.connect,
          message: 'a',
        );
        final emissions = <int>[];
        final sub = store.stream.listen((s) => emissions.add(s.length));
        store.clear();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions, [0]);
        await sub.cancel();
        await store.dispose();
      },
    );

    test(
      'stream fires on pause / resume so the UI can update the chip',
      () async {
        final store = MeshCoreBleDebugLogStore();
        final emissions = <int>[];
        final sub = store.stream.listen((s) => emissions.add(s.length));
        store.pause();
        store.resume();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions, [0, 0]);
        await sub.cancel();
        await store.dispose();
      },
    );
  });

  group('redactMacFingerprint', () {
    test('colon-separated MAC reduces to last 4 hex', () {
      expect(redactMacFingerprint('AA:BB:CC:DD:EE:FF'), 'EE:FF');
    });

    test('hyphen-separated MAC reduces to last 4 hex', () {
      expect(redactMacFingerprint('aa-bb-cc-dd-ee-ff'), 'EE:FF');
    });

    test('no-separator MAC reduces to last 4 hex', () {
      expect(redactMacFingerprint('AABBCCDDEEFF'), 'EE:FF');
    });

    test('mixed-case MAC normalises to uppercase last 4 hex', () {
      expect(redactMacFingerprint('aa:bb:cc:dd:Ee:fF'), 'EE:FF');
    });

    test('null input returns XX:XX (no leakage on missing data)', () {
      expect(redactMacFingerprint(null), 'XX:XX');
    });

    test('empty input returns XX:XX', () {
      expect(redactMacFingerprint(''), 'XX:XX');
    });

    test('too-short input returns XX:XX', () {
      expect(redactMacFingerprint('AB'), 'XX:XX');
    });

    test('non-hex characters are stripped', () {
      expect(redactMacFingerprint('xyzAABBCCDDEEFFqqq'), 'EE:FF');
    });
  });

  group('redactServiceUuids', () {
    test('truncates each UUID to the first 8 hex with an ellipsis', () {
      expect(
        redactServiceUuids([
          '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
          '00001800-0000-1000-8000-00805F9B34FB',
        ]),
        '6e400001…, 00001800…',
      );
    });

    test('short UUIDs (e.g. 16-bit) pass through lowercased', () {
      expect(redactServiceUuids(['1800', 'AABB']), '1800, aabb');
    });

    test('non-hex separators in UUIDs are stripped before truncation', () {
      // 12345678-9abc-def0-... → cleaned `123456789abcdef0...`
      // → first 8 hex `12345678` + ellipsis.
      expect(
        redactServiceUuids(['12345678-9abc-def0-1234-56789abcdef0']),
        '12345678…',
      );
    });
  });

  group('formatByteCount', () {
    test('returns "N B"', () {
      expect(formatByteCount(Uint8List.fromList([1, 2, 3])), '3 B');
    });

    test('zero-length returns "0 B"', () {
      expect(formatByteCount(Uint8List(0)), '0 B');
    });
  });
}
