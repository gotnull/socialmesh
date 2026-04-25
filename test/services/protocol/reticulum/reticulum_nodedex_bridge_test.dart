// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_fragment_event.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_nodedex_bridge.dart';

void main() {
  group('ReticulumNodeDexBridge — keyForEvent', () {
    test('uses packetId when present', () {
      final event = ReticulumFragmentEvent(
        timestampMs: 0,
        fromNode: 0xAA,
        toNode: 0,
        packetId: 0x1234,
        channel: 0,
        rssi: null,
        snr: null,
        payload: Uint8List(8),
      );
      expect(ReticulumNodeDexBridge.keyForEvent(event), 'pid:170:4660');
    });

    test('falls back to payload prefix when packetId is 0', () {
      final event = ReticulumFragmentEvent(
        timestampMs: 0,
        fromNode: 7,
        toNode: 0,
        packetId: 0,
        channel: 0,
        rssi: null,
        snr: null,
        payload: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
      );
      expect(ReticulumNodeDexBridge.keyForEvent(event), 'sig:7:deadbeef');
    });

    test('signature truncates to 16 bytes', () {
      final event = ReticulumFragmentEvent(
        timestampMs: 0,
        fromNode: 0,
        toNode: 0,
        packetId: 0,
        channel: 0,
        rssi: null,
        snr: null,
        payload: Uint8List(64)..fillRange(0, 64, 0xCC),
      );
      final key = ReticulumNodeDexBridge.keyForEvent(event);
      // 16 bytes * 2 hex chars = 32 hex chars after the sig:0: prefix.
      final hexPortion = key.substring('sig:0:'.length);
      expect(hexPortion.length, 32);
    });
  });

  group('ReticulumNodeDexBridge — dedup window', () {
    test('first event records; duplicate within window does not', () {
      final calls = <int>[];
      final times = <DateTime>[
        DateTime(2026, 1, 1, 12, 0, 0),
        DateTime(2026, 1, 1, 12, 1, 0), // 60s later — within 5min window
      ];
      var idx = 0;
      final bridge = ReticulumNodeDexBridge(
        recordEncounter: (id, _) => calls.add(id),
        clock: () => times[idx],
      );
      final event = _event(packetId: 42);

      bridge.onFragment(event);
      idx = 1;
      bridge.onFragment(event);

      expect(calls, [event.fromNode]);
    });

    test('duplicate after window expires records again', () {
      final calls = <int>[];
      final times = <DateTime>[
        DateTime(2026, 1, 1, 12, 0, 0),
        DateTime(2026, 1, 1, 12, 6, 0), // 6 min later — past 5min window
      ];
      var idx = 0;
      final bridge = ReticulumNodeDexBridge(
        recordEncounter: (id, _) => calls.add(id),
        clock: () => times[idx],
      );
      final event = _event(packetId: 42);

      bridge.onFragment(event);
      idx = 1;
      bridge.onFragment(event);

      expect(calls, [event.fromNode, event.fromNode]);
    });

    test('different packetIds from same source are independent', () {
      final calls = <int>[];
      final bridge = ReticulumNodeDexBridge(
        recordEncounter: (id, _) => calls.add(id),
      );
      bridge.onFragment(_event(packetId: 1));
      bridge.onFragment(_event(packetId: 2));
      bridge.onFragment(_event(packetId: 3));
      expect(calls, hasLength(3));
    });

    test('expired keys are pruned after each call', () {
      final times = [
        DateTime(2026, 1, 1, 12, 0, 0),
        DateTime(2026, 1, 1, 12, 0, 10),
        DateTime(2026, 1, 1, 12, 10, 0),
      ];
      var idx = 0;
      final bridge = ReticulumNodeDexBridge(
        recordEncounter: (_, _) {},
        clock: () => times[idx],
      );
      bridge.onFragment(_event(packetId: 1));
      idx = 1;
      bridge.onFragment(_event(packetId: 2));
      expect(bridge.cachedKeyCount, 2);
      idx = 2;
      bridge.onFragment(_event(packetId: 3));
      // Old keys (1 and 2) should now be pruned, leaving only key 3.
      expect(bridge.cachedKeyCount, 1);
    });
  });
}

ReticulumFragmentEvent _event({required int packetId}) {
  return ReticulumFragmentEvent(
    timestampMs: DateTime.now().millisecondsSinceEpoch,
    fromNode: 0xAABB,
    toNode: 0xFFFFFFFF,
    packetId: packetId,
    channel: 0,
    rssi: null,
    snr: null,
    payload: Uint8List(4),
  );
}
