// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A2: `MeshCoreSendConfirmationRouter` pins.
//
// Pinned invariants:
//   - A matching 0x82 push (frame.command == 0x82) with the
//     expected ack-hash at payload[0..4] completes the waiter as
//     `delivered: true` + the trip time from payload[4..8].
//   - A mismatched ack-hash does NOT complete the waiter.
//   - Frames whose command isn't 0x82 are ignored even when the
//     payload bytes happen to match.
//   - A short payload (<8 bytes) is dropped silently; defensive
//     against firmware versions that change the layout.
//   - The waiter times out cleanly when no matching push arrives
//     within the timeout.
//   - Re-registering the same hash while a prior waiter is pending
//     completes the prior one as timed-out.
//   - `dispose()` completes outstanding waiters as timed-out and
//     unsubscribes from the upstream stream.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_send_confirmation_router.dart';

MeshCoreFrame _confirmedFrame({required int ackHash, int tripMs = 100}) {
  final payload = Uint8List(8);
  payload.buffer.asByteData().setUint32(0, ackHash, Endian.little);
  payload.buffer.asByteData().setUint32(4, tripMs, Endian.little);
  return MeshCoreFrame(
    command: MeshCorePushCodes.sendConfirmed,
    payload: payload,
  );
}

void main() {
  late StreamController<MeshCoreFrame> source;
  late MeshCoreSendConfirmationRouter router;

  setUp(() {
    source = StreamController<MeshCoreFrame>.broadcast();
    router = MeshCoreSendConfirmationRouter(frameStream: source.stream);
  });

  tearDown(() async {
    await router.dispose();
    await source.close();
  });

  group('MeshCoreSendConfirmationRouter - D48-A2', () {
    test('matching 0x82 push completes the waiter as delivered', () async {
      final future = router.waitForDelivery(
        ackHash: 0xABCDEF12,
        timeout: const Duration(seconds: 5),
      );
      source.add(_confirmedFrame(ackHash: 0xABCDEF12, tripMs: 250));
      final outcome = await future;
      expect(outcome.delivered, isTrue);
      expect(outcome.tripTime, equals(const Duration(milliseconds: 250)));
    });

    test('mismatched ack-hash does NOT complete the waiter', () async {
      final future = router.waitForDelivery(
        ackHash: 0xDEAD0001,
        timeout: const Duration(milliseconds: 200),
      );
      source.add(_confirmedFrame(ackHash: 0xDEAD0002));
      final outcome = await future;
      expect(outcome.delivered, isFalse);
    });

    test(
      'frames whose command isnt 0x82 are ignored (no false positives)',
      () async {
        final future = router.waitForDelivery(
          ackHash: 0xAA,
          timeout: const Duration(milliseconds: 200),
        );
        // Build a frame with matching bytes but a different command code.
        final payload = Uint8List(8);
        payload.buffer.asByteData().setUint32(0, 0xAA, Endian.little);
        source.add(MeshCoreFrame(command: 0x83, payload: payload));
        final outcome = await future;
        expect(outcome.delivered, isFalse);
      },
    );

    test('payload shorter than 8 bytes is dropped silently', () async {
      final future = router.waitForDelivery(
        ackHash: 0x1234,
        timeout: const Duration(milliseconds: 200),
      );
      source.add(
        MeshCoreFrame(
          command: MeshCorePushCodes.sendConfirmed,
          payload: Uint8List(3),
        ),
      );
      final outcome = await future;
      expect(outcome.delivered, isFalse);
    });

    test('times out when no matching push arrives', () async {
      final stopwatch = Stopwatch()..start();
      final outcome = await router.waitForDelivery(
        ackHash: 0xFF,
        timeout: const Duration(milliseconds: 150),
      );
      stopwatch.stop();
      expect(outcome.delivered, isFalse);
      expect(outcome.tripTime, isNull);
      expect(
        stopwatch.elapsedMilliseconds,
        greaterThanOrEqualTo(140),
        reason: 'waiter must respect the timeout it was given',
      );
    });

    test(
      're-registering the same hash completes the prior waiter as timed-out',
      () async {
        final first = router.waitForDelivery(
          ackHash: 0x42,
          timeout: const Duration(seconds: 5),
        );
        // Register a second waiter for the same hash immediately.
        final second = router.waitForDelivery(
          ackHash: 0x42,
          timeout: const Duration(seconds: 5),
        );
        // The first one should complete as not-delivered without
        // waiting for its timer.
        final firstOutcome = await first;
        expect(firstOutcome.delivered, isFalse);
        // The second waiter should still pick up the next match.
        source.add(_confirmedFrame(ackHash: 0x42, tripMs: 80));
        final secondOutcome = await second;
        expect(secondOutcome.delivered, isTrue);
        expect(secondOutcome.tripTime?.inMilliseconds, equals(80));
      },
    );

    test('dispose completes outstanding waiters as timed-out', () async {
      final future = router.waitForDelivery(
        ackHash: 0x77,
        timeout: const Duration(seconds: 30),
      );
      await router.dispose();
      final outcome = await future;
      expect(outcome.delivered, isFalse);
    });
  });
}
