// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_safe_log.dart';

void main() {
  group('ReticulumSafeLog — payload-byte safety contract', () {
    test('public methods accept only metadata fields', () {
      // This test exists as a guard against accidental API drift. Every
      // ReticulumSafeLog method below MUST be callable using only
      // primitives — never a Uint8List or List<int> payload buffer.
      // If a future change introduces a `Uint8List payload` parameter,
      // the build will fail here with a missing/changed argument.
      ReticulumSafeLog.event('observability event');
      ReticulumSafeLog.fragmentReceived(
        fromNode: 0x11,
        toNode: 0xFFFFFFFF,
        packetId: 42,
        channel: 0,
        payloadLen: 16,
        rssi: -80,
        snr: 3.0,
      );
      ReticulumSafeLog.capture(action: 'open', path: '/tmp/x.bin');
      ReticulumSafeLog.replay(
        action: 'start',
        path: '/tmp/x.bin',
        recordIndex: 0,
        totalRecords: 5,
        mode: 'realtime',
      );
      ReticulumSafeLog.decodeError(reason: 'truncated', offset: 27);
    });
  });
}
