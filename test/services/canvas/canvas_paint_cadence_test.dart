// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Unit pin for the mesh-canvas paint-cadence gate. Tap-layer scarcity
// so users can't generate confetti faster than the radio can carry it.
//
// Spec: anti-spam brief item 1 ("Per-user mesh paint cadence").

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/canvas/canvas_constants.dart';
import 'package:socialmesh/services/canvas/canvas_paint_cadence.dart';

void main() {
  group('CanvasPaintCadence', () {
    test('first tap on a canvas is not cooling', () {
      final cadence = CanvasPaintCadence(nowMs: () => 1000);
      expect(cadence.isCoolingDown(42), isFalse);
    });

    test('tap recorded -> immediately cooling for the interval', () {
      var now = 1000;
      final cadence = CanvasPaintCadence(nowMs: () => now);
      cadence.recordTap(42);
      expect(cadence.isCoolingDown(42), isTrue);

      // 1 ms before the interval elapses: still cooling.
      now = 1000 + CanvasCadence.meshTapInterval.inMilliseconds - 1;
      expect(cadence.isCoolingDown(42), isTrue);

      // Exactly at the interval boundary: no longer cooling.
      now = 1000 + CanvasCadence.meshTapInterval.inMilliseconds;
      expect(cadence.isCoolingDown(42), isFalse);
    });

    test(
      'cadence is per-canvas — a tap on canvas A does not gate canvas B',
      () {
        final cadence = CanvasPaintCadence(nowMs: () => 1000);
        cadence.recordTap(1);
        expect(cadence.isCoolingDown(1), isTrue);
        expect(
          cadence.isCoolingDown(2),
          isFalse,
          reason:
              'A user painting on Primary should still be able to paint on '
              'TestChannel immediately. The gate is per-canvas.',
        );
      },
    );

    test('msUntilReady is zero before any tap', () {
      final cadence = CanvasPaintCadence(nowMs: () => 1000);
      expect(cadence.msUntilReady(42), 0);
    });

    test('msUntilReady decreases as the clock advances', () {
      var now = 1000;
      final cadence = CanvasPaintCadence(nowMs: () => now);
      cadence.recordTap(42);
      expect(
        cadence.msUntilReady(42),
        CanvasCadence.meshTapInterval.inMilliseconds,
      );
      now += 500;
      expect(
        cadence.msUntilReady(42),
        CanvasCadence.meshTapInterval.inMilliseconds - 500,
      );
      now = 1000 + CanvasCadence.meshTapInterval.inMilliseconds + 1;
      expect(cadence.msUntilReady(42), 0);
    });

    test('changes stream emits the canvasLocalId on every recordTap', () async {
      final cadence = CanvasPaintCadence(nowMs: () => 1000);
      final received = <int>[];
      final sub = cadence.changes.listen(received.add);
      cadence.recordTap(1);
      cadence.recordTap(2);
      cadence.recordTap(1);
      await Future<void>.delayed(Duration.zero);
      expect(received, [1, 2, 1]);
      await sub.cancel();
      cadence.dispose();
    });

    test('dispose is idempotent and clears state', () {
      final cadence = CanvasPaintCadence(nowMs: () => 1000);
      cadence.recordTap(1);
      cadence.dispose();
      // resetForTest after dispose should not throw.
      expect(() => cadence.resetForTest(), returnsNormally);
    });
  });
}
