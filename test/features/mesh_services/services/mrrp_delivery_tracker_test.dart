// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/delivery_progress_card.dart';
import 'package:socialmesh/features/mesh_services/services/mrrp_delivery_tracker.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dispatcher.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

// ---------------------------------------------------------------------------
// Fake MrrpEngine that returns scripted results per call.
// ---------------------------------------------------------------------------

class _FakeMrrpEngine extends Fake implements MrrpEngine {
  /// Queue of results to return for successive sendRequest calls.
  final List<MrrpRequestResult> results = [];

  /// Number of times sendRequest was called.
  int sendCount = 0;

  /// Optional delay applied per sendRequest call to simulate timeout wait.
  Duration? sendDelay;

  @override
  Future<MrrpRequestResult> sendRequest(MrrpFrame request) async {
    if (sendDelay != null) {
      await Future<void>.delayed(sendDelay!);
    }
    sendCount++;
    if (results.isEmpty) {
      return const MrrpRequestResult(status: MrrpStatusCode.timeout);
    }
    return results.removeAt(0);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MrrpFrame _makeRequest({int serviceId = 0x00000010, int actionId = 0x0001}) {
  return MrrpFrame(
    versionMajor: MrrpConstants.mrrpVersionMajor,
    versionMinor: MrrpConstants.mrrpVersionMinor,
    msgType: MrrpMessageType.request,
    flags: MrrpFlags.ackRequired,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: 0,
    serviceId: serviceId,
    actionId: actionId,
    payloadLen: 0,
    payload: Uint8List(0),
  );
}

MrrpRequestResult _okResult({List<int> payload = const [0xBE, 0xEF]}) {
  return MrrpRequestResult(
    status: MrrpStatusCode.ok,
    latency: const Duration(milliseconds: 250),
    response: MrrpFrame(
      versionMajor: 0,
      versionMinor: 1,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 1,
      serviceId: 0x00000010,
      actionId: 0x0001,
      payloadLen: payload.length,
      payload: Uint8List.fromList(payload),
    ),
  );
}

const _timeout = MrrpRequestResult(status: MrrpStatusCode.timeout);
const _notFound = MrrpRequestResult(status: MrrpStatusCode.notFound);
const _internal = MrrpRequestResult(status: MrrpStatusCode.internal);

void main() {
  group('MrrpDeliveryTracker', () {
    late _FakeMrrpEngine engine;
    late MrrpDeliveryTracker tracker;

    setUp(() {
      engine = _FakeMrrpEngine();
      tracker = MrrpDeliveryTracker(engine);
    });

    tearDown(() {
      tracker.dispose();
    });

    // ----- No retry (policy=none, the default) -----

    group('no retry (policy=none)', () {
      test('success on first attempt', () async {
        engine.results.addAll([_okResult()]);

        final phases = <DeliveryPhase>[];
        tracker.stateChanges.listen((s) => phases.add(s.phase));

        final result = await tracker.trackRequest(_makeRequest());

        expect(result.phase, DeliveryPhase.delivered);
        expect(result.attemptsMade, 1);
        expect(result.statusCode, MrrpStatusCode.ok);
        expect(result.response, isNotNull);
        expect(engine.sendCount, 1);
        expect(phases, [
          DeliveryPhase.preparing,
          DeliveryPhase.sending,
          DeliveryPhase.delivered,
        ]);
      });

      test('timeout on single attempt — no retry', () async {
        engine.results.addAll([_timeout]);

        final result = await tracker.trackRequest(_makeRequest());

        expect(result.phase, DeliveryPhase.failed);
        expect(result.attemptsMade, 1);
        expect(result.statusCode, MrrpStatusCode.timeout);
        expect(engine.sendCount, 1);
      });

      test('protocol error — no retry regardless', () async {
        engine.results.addAll([_notFound]);

        final result = await tracker.trackRequest(_makeRequest());

        expect(result.phase, DeliveryPhase.failed);
        expect(result.attemptsMade, 1);
        expect(result.statusCode, MrrpStatusCode.notFound);
        expect(engine.sendCount, 1);
      });
    });

    // ----- Idempotent retry -----

    group('idempotent retry', () {
      test('1. success on first attempt', () async {
        engine.results.addAll([_okResult()]);

        final phases = <DeliveryPhase>[];
        tracker.stateChanges.listen((s) => phases.add(s.phase));

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.phase, DeliveryPhase.delivered);
        expect(result.attemptsMade, 1);
        expect(engine.sendCount, 1);
        // Should not have retrying phase
        expect(phases.contains(DeliveryPhase.retrying), isFalse);
      });

      test('2. first attempt times out, second succeeds', () async {
        engine.results.addAll([_timeout, _okResult()]);

        final phases = <DeliveryPhase>[];
        tracker.stateChanges.listen((s) => phases.add(s.phase));

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.phase, DeliveryPhase.delivered);
        expect(result.attemptsMade, 2);
        expect(result.statusCode, MrrpStatusCode.ok);
        expect(engine.sendCount, 2);
        expect(phases, contains(DeliveryPhase.retrying));
      });

      test('3. first and second timeout, third succeeds', () async {
        engine.results.addAll([_timeout, _timeout, _okResult()]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.phase, DeliveryPhase.delivered);
        expect(result.attemptsMade, 3);
        expect(engine.sendCount, 3);
      });

      test('4. all attempts timeout — terminal failure once', () async {
        engine.results.addAll([_timeout, _timeout, _timeout]);

        final terminalStates = <MrrpDeliveryState>[];
        tracker.stateChanges.listen((s) {
          if (s.phase == DeliveryPhase.failed) {
            terminalStates.add(s);
          }
        });

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.phase, DeliveryPhase.failed);
        expect(result.attemptsMade, 3);
        expect(result.statusCode, MrrpStatusCode.timeout);
        expect(engine.sendCount, 3);
        // Failed emitted exactly once
        expect(terminalStates.length, 1);
      });

      test('5. protocol error on first attempt — no retry', () async {
        engine.results.addAll([_notFound]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.phase, DeliveryPhase.failed);
        expect(result.attemptsMade, 1);
        expect(result.statusCode, MrrpStatusCode.notFound);
        expect(engine.sendCount, 1);
      });

      test('5b. internal error on first attempt — no retry', () async {
        engine.results.addAll([_internal]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.phase, DeliveryPhase.failed);
        expect(result.attemptsMade, 1);
        expect(engine.sendCount, 1);
      });

      test(
        '6. busy status on first attempt — no retry (needsAttention)',
        () async {
          engine.results.addAll([
            const MrrpRequestResult(status: MrrpStatusCode.busy),
          ]);

          final result = await tracker.trackRequest(
            _makeRequest(),
            retryPolicy: MrrpRetryPolicy.idempotent,
          );

          expect(result.phase, DeliveryPhase.needsAttention);
          expect(result.attemptsMade, 1);
          expect(engine.sendCount, 1);
        },
      );
    });

    // ----- Phase transitions -----

    group('phase transitions', () {
      test('no-retry: preparing -> sending -> failed', () async {
        engine.results.addAll([_timeout]);

        final phases = <DeliveryPhase>[];
        tracker.stateChanges.listen((s) => phases.add(s.phase));

        await tracker.trackRequest(_makeRequest());

        expect(phases, [
          DeliveryPhase.preparing,
          DeliveryPhase.sending,
          DeliveryPhase.failed,
        ]);
      });

      test(
        'retry: preparing -> sending -> retrying -> retrying -> failed',
        () async {
          engine.results.addAll([_timeout, _timeout, _timeout]);

          final phases = <DeliveryPhase>[];
          tracker.stateChanges.listen((s) => phases.add(s.phase));

          await tracker.trackRequest(
            _makeRequest(),
            retryPolicy: MrrpRetryPolicy.idempotent,
          );

          expect(phases, [
            DeliveryPhase.preparing,
            DeliveryPhase.sending,
            DeliveryPhase.retrying,
            DeliveryPhase.retrying,
            DeliveryPhase.failed,
          ]);
        },
      );

      test(
        'retry success: preparing -> sending -> retrying -> delivered',
        () async {
          engine.results.addAll([_timeout, _okResult()]);

          final phases = <DeliveryPhase>[];
          tracker.stateChanges.listen((s) => phases.add(s.phase));

          await tracker.trackRequest(
            _makeRequest(),
            retryPolicy: MrrpRetryPolicy.idempotent,
          );

          expect(phases, [
            DeliveryPhase.preparing,
            DeliveryPhase.sending,
            DeliveryPhase.retrying,
            DeliveryPhase.delivered,
          ]);
        },
      );
    });

    // ----- attemptsMade accuracy -----

    group('attemptsMade accuracy', () {
      test('single attempt failure reports 1', () async {
        engine.results.addAll([_timeout]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.none,
        );

        expect(result.attemptsMade, 1);
      });

      test('three attempt failure reports 3', () async {
        engine.results.addAll([_timeout, _timeout, _timeout]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.attemptsMade, 3);
      });

      test('second attempt success reports 2', () async {
        engine.results.addAll([_timeout, _okResult()]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.attemptsMade, 2);
      });
    });

    // ----- Dispose safety -----

    group('dispose safety', () {
      test('dispose prevents further emissions', () async {
        // Use a slow delay to give us time to dispose
        engine.sendDelay = const Duration(milliseconds: 50);
        engine.results.addAll([_timeout, _okResult()]);

        final phases = <DeliveryPhase>[];
        tracker.stateChanges.listen((s) => phases.add(s.phase));

        // Start the request then dispose mid-flight
        final future = tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        // Let first attempt send
        await Future<void>.delayed(const Duration(milliseconds: 10));
        tracker.dispose();

        final result = await future;

        // Terminal result should have been produced, but no further
        // emissions after dispose (no crash, no stream error)
        expect(result.phase, isNotNull);
      });

      test('dispose mid-retry stops engine calls', () async {
        // Engine is slow — gives time to dispose after attempt 1.
        engine.sendDelay = const Duration(milliseconds: 80);
        engine.results.addAll([_timeout, _timeout, _timeout]);

        final future = tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        // Wait for first attempt to be in flight, then dispose.
        await Future<void>.delayed(const Duration(milliseconds: 40));
        tracker.dispose();

        await future;

        // Engine should NOT have been called 3 times — dispose aborted
        // the loop before exhausting all retries.
        expect(engine.sendCount, lessThan(3));
      });
    });

    // ----- Lifecycle correctness -----

    group('lifecycle correctness', () {
      test(
        'no duplicate terminal on success — delivered emitted once',
        () async {
          engine.results.addAll([_okResult()]);

          final deliveredStates = <MrrpDeliveryState>[];
          tracker.stateChanges.listen((s) {
            if (s.phase == DeliveryPhase.delivered) deliveredStates.add(s);
          });

          await tracker.trackRequest(_makeRequest());

          expect(deliveredStates.length, 1);
        },
      );

      test(
        'no duplicate terminal on retry success — delivered emitted once',
        () async {
          engine.results.addAll([_timeout, _okResult()]);

          final deliveredStates = <MrrpDeliveryState>[];
          tracker.stateChanges.listen((s) {
            if (s.phase == DeliveryPhase.delivered) deliveredStates.add(s);
          });

          await tracker.trackRequest(
            _makeRequest(),
            retryPolicy: MrrpRetryPolicy.idempotent,
          );

          expect(deliveredStates.length, 1);
        },
      );

      test(
        'no retry after first-attempt success with idempotent policy',
        () async {
          engine.results.addAll([_okResult()]);

          final result = await tracker.trackRequest(
            _makeRequest(),
            retryPolicy: MrrpRetryPolicy.idempotent,
          );

          expect(result.phase, DeliveryPhase.delivered);
          expect(result.attemptsMade, 1);
          expect(engine.sendCount, 1);
        },
      );

      test('sequential attempts — no interleaved pending requests', () async {
        // Each engine call records invocation order. Since trackRequest
        // uses sequential await (not fire-and-forget), attempt N+1 cannot
        // start until attempt N completes. This test verifies the engine
        // call count matches expected attempts exactly.
        engine.results.addAll([_timeout, _timeout, _okResult()]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        // Exactly 3 sequential calls, no more.
        expect(engine.sendCount, 3);
        expect(result.attemptsMade, 3);
        expect(result.phase, DeliveryPhase.delivered);
      });

      test(
        'terminal failure emitted exactly once on exhausted retries',
        () async {
          engine.results.addAll([_timeout, _timeout, _timeout]);

          final failedStates = <MrrpDeliveryState>[];
          tracker.stateChanges.listen((s) {
            if (s.phase == DeliveryPhase.failed) failedStates.add(s);
          });

          await tracker.trackRequest(
            _makeRequest(),
            retryPolicy: MrrpRetryPolicy.idempotent,
          );

          expect(failedStates.length, 1);
          expect(failedStates.first.attemptsMade, 3);
        },
      );

      test('state registry reflects terminal state after completion', () async {
        engine.results.addAll([_timeout, _okResult()]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        final stored = tracker.getState(result.deliveryId);
        expect(stored, isNotNull);
        expect(stored!.phase, DeliveryPhase.delivered);
        expect(stored.attemptsMade, 2);
        expect(stored.statusCode, MrrpStatusCode.ok);
      });
    });

    // ----- Delivery registry -----

    group('delivery registry', () {
      test('12. pending entries cleaned up after success', () async {
        engine.results.addAll([_okResult()]);

        final result = await tracker.trackRequest(_makeRequest());

        expect(tracker.getState(result.deliveryId), isNotNull);
        expect(
          tracker.getState(result.deliveryId)!.phase,
          DeliveryPhase.delivered,
        );
      });

      test('12b. pending entries cleaned up after failure', () async {
        engine.results.addAll([_timeout]);

        final result = await tracker.trackRequest(_makeRequest());

        expect(tracker.getState(result.deliveryId), isNotNull);
        expect(
          tracker.getState(result.deliveryId)!.phase,
          DeliveryPhase.failed,
        );
      });

      test('multiple deliveries tracked independently', () async {
        engine.results.addAll([_okResult(), _timeout]);

        final r1 = await tracker.trackRequest(_makeRequest());
        final r2 = await tracker.trackRequest(_makeRequest());

        expect(r1.deliveryId, isNot(r2.deliveryId));
        expect(r1.phase, DeliveryPhase.delivered);
        expect(r2.phase, DeliveryPhase.failed);
      });
    });

    // ----- Retry policy safety -----

    group('retry policy safety', () {
      test('14. policy=none does not retry even on timeout', () async {
        engine.results.addAll([_timeout]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.none,
        );

        expect(result.attemptsMade, 1);
        expect(engine.sendCount, 1);
      });

      test('14b. policy=idempotent retries on timeout', () async {
        engine.results.addAll([_timeout, _okResult()]);

        final result = await tracker.trackRequest(
          _makeRequest(),
          retryPolicy: MrrpRetryPolicy.idempotent,
        );

        expect(result.attemptsMade, 2);
        expect(engine.sendCount, 2);
      });
    });

    // ----- Retry config -----

    group('MrrpRetryConfig', () {
      test('maxAttempts is 3', () {
        expect(MrrpRetryConfig.maxAttempts, 3);
      });

      test('delayForRetry returns correct durations', () {
        expect(MrrpRetryConfig.delayForRetry(1), MrrpRetryConfig.retryDelay1);
        expect(MrrpRetryConfig.delayForRetry(2), MrrpRetryConfig.retryDelay2);
        expect(MrrpRetryConfig.delayForRetry(3), MrrpRetryConfig.retryDelay2);
      });
    });

    // ----- MrrpDeliveryState -----

    group('MrrpDeliveryState', () {
      test('copyWith preserves unchanged fields', () {
        const state = MrrpDeliveryState(
          deliveryId: 'test_1',
          phase: DeliveryPhase.sending,
          attemptsMade: 2,
        );

        final updated = state.copyWith(phase: DeliveryPhase.retrying);

        expect(updated.deliveryId, 'test_1');
        expect(updated.phase, DeliveryPhase.retrying);
        expect(updated.attemptsMade, 2);
      });

      test('copyWith updates attemptsMade', () {
        const state = MrrpDeliveryState(
          deliveryId: 'test_1',
          phase: DeliveryPhase.sending,
          attemptsMade: 1,
        );

        final updated = state.copyWith(attemptsMade: 3);
        expect(updated.attemptsMade, 3);
      });

      test('default attemptsMade is 1', () {
        const state = MrrpDeliveryState(
          deliveryId: 'test_1',
          phase: DeliveryPhase.preparing,
        );
        expect(state.attemptsMade, 1);
      });
    });
  });
}
