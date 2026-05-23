// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for MeshCanvasTransmissionStatus + CanvasPendingStats value
// types and the severity derivation rules.
//
// Spec: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §2.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/canvas/canvas_transmission_status_models.dart';

void main() {
  group('MeshCanvasTransmissionStatus.derive — severity precedence', () {
    test('empty queue + healthy budgets → idle', () {
      final status = MeshCanvasTransmissionStatus.derive(
        pendingCount: 0,
        oldestPendingAtMs: null,
        nextAttemptAtMs: null,
        governorRemainingBytes: 250,
        lastSipDenialAtMs: null,
        nowMs: 1_000_000,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.idle);
      expect(status.canPaint, isTrue);
      expect(status.isCanvasBudgetCooling, isFalse);
      expect(status.isSipBudgetCooling, isFalse);
    });

    test('one row queued + healthy budgets → queued', () {
      final status = MeshCanvasTransmissionStatus.derive(
        pendingCount: 1,
        oldestPendingAtMs: 999_900,
        nextAttemptAtMs: 1_000_500,
        governorRemainingBytes: 250,
        lastSipDenialAtMs: null,
        nowMs: 1_000_000,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.queued);
      expect(status.canPaint, isTrue);
    });

    test(
      'governor headroom < minPaintBytes (24) → cooling regardless of count',
      () {
        final status = MeshCanvasTransmissionStatus.derive(
          pendingCount: 1,
          oldestPendingAtMs: 999_900,
          nextAttemptAtMs: 1_000_500,
          // Below the 24-byte minPaint threshold.
          governorRemainingBytes: 10,
          lastSipDenialAtMs: null,
          nowMs: 1_000_000,
        );
        expect(status.severity, MeshCanvasTransmissionSeverity.cooling);
        expect(status.isCanvasBudgetCooling, isTrue);
        expect(status.canPaint, isTrue);
      },
    );

    test('recent SIP denial within 5s window → cooling even when canvas '
        'budget is full', () {
      final status = MeshCanvasTransmissionStatus.derive(
        pendingCount: 3,
        oldestPendingAtMs: 999_000,
        nextAttemptAtMs: 1_002_000,
        governorRemainingBytes: 250,
        lastSipDenialAtMs: 998_000, // 2 s ago, within 5 s window
        nowMs: 1_000_000,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.cooling);
      expect(status.isSipBudgetCooling, isTrue);
    });

    test('SIP denial outside 5s window → no SIP cooling', () {
      final status = MeshCanvasTransmissionStatus.derive(
        pendingCount: 3,
        oldestPendingAtMs: 999_000,
        nextAttemptAtMs: 1_002_000,
        governorRemainingBytes: 250,
        lastSipDenialAtMs: 990_000, // 10 s ago, outside window
        nowMs: 1_000_000,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.queued);
      expect(status.isSipBudgetCooling, isFalse);
    });

    test('pendingCount >= softQueueCap (32) → full, regardless of budget state '
        '— blocks new paint taps', () {
      final status = MeshCanvasTransmissionStatus.derive(
        pendingCount: 32,
        oldestPendingAtMs: 999_000,
        nextAttemptAtMs: 1_002_000,
        governorRemainingBytes: 250, // budget would otherwise allow more
        lastSipDenialAtMs: null,
        nowMs: 1_000_000,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.full);
      expect(
        status.canPaint,
        isFalse,
        reason: 'queue full must block new paint taps',
      );
    });

    test('full has precedence over cooling — block before showing cooling', () {
      final status = MeshCanvasTransmissionStatus.derive(
        pendingCount: 50,
        oldestPendingAtMs: 999_000,
        nextAttemptAtMs: 1_002_000,
        governorRemainingBytes: 0, // cooling
        lastSipDenialAtMs: 999_500, // cooling
        nowMs: 1_000_000,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.full);
      expect(status.canPaint, isFalse);
      expect(status.isCanvasBudgetCooling, isTrue);
      expect(status.isSipBudgetCooling, isTrue);
    });
  });

  group('MeshCanvasTransmissionStatus — identity + idle constant', () {
    test('idle constant is the conservative empty state', () {
      const i = MeshCanvasTransmissionStatus.idle;
      expect(i.severity, MeshCanvasTransmissionSeverity.idle);
      expect(i.pendingCount, 0);
      expect(i.canPaint, isTrue);
      expect(i.isCanvasBudgetCooling, isFalse);
      expect(i.isSipBudgetCooling, isFalse);
    });

    test('soft queue cap is 32 (NOT the lossy 256 hard cap)', () {
      expect(MeshCanvasTransmissionStatus.softQueueCap, 32);
    });

    test('minimum paint bytes matches the paint (0x0001) frame size', () {
      expect(MeshCanvasTransmissionStatus.minPaintBytes, 24);
    });

    test('equality + hashCode by field', () {
      const a = MeshCanvasTransmissionStatus.idle;
      final b = MeshCanvasTransmissionStatus.derive(
        pendingCount: 0,
        oldestPendingAtMs: null,
        nextAttemptAtMs: null,
        governorRemainingBytes: 250,
        lastSipDenialAtMs: null,
        nowMs: 1_000_000,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('CanvasPendingStats', () {
    test('empty constant is the (0, null, null) state', () {
      const e = CanvasPendingStats.empty;
      expect(e.count, 0);
      expect(e.oldestCreatedAtMs, isNull);
      expect(e.nextAttemptAtMs, isNull);
    });

    test('equality matches by field', () {
      const a = CanvasPendingStats(
        count: 3,
        oldestCreatedAtMs: 1_000,
        nextAttemptAtMs: 2_000,
      );
      const b = CanvasPendingStats(
        count: 3,
        oldestCreatedAtMs: 1_000,
        nextAttemptAtMs: 2_000,
      );
      const c = CanvasPendingStats(
        count: 4,
        oldestCreatedAtMs: 1_000,
        nextAttemptAtMs: 2_000,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
