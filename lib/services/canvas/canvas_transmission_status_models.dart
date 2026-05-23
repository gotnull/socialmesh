// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas transmission status value types.
//
// Source of truth: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §2.
//
// Surfaces airtime + queue state from the canvas governor, SIP rate
// limiter, and pending_op table so the UI tier can show users that
// their paints landed locally but are still in flight on the mesh.
//
// Mesh-scope only — local Device Canvas never enqueues to `pending_op`
// and is structurally idle. The view model returns
// `MeshCanvasTransmissionStatus.idle` for non-mesh inputs as a
// defensive default so consumers don't need to branch on scope.
library;

import 'package:flutter/foundation.dart';

/// Coarse severity bucket driving HUD label + paint-block gate.
///
/// Order matters: severity is derived by first-match precedence in the
/// view model (`full > cooling > queued > idle`).
enum MeshCanvasTransmissionSeverity {
  /// No pending paints, no cooling. HUD is hidden entirely.
  idle,

  /// At least one paint is queued but the wire is moving — the user
  /// just needs to be aware it's in flight, not blocked.
  queued,

  /// Canvas governor OR SIP rate limiter is currently refusing
  /// frames. New paints below the soft cap are still accepted into
  /// the queue.
  cooling,

  /// Pending queue has hit the UX soft cap. New paint taps are
  /// blocked until the queue drains. NOT the hard 256 lossy-collapse
  /// cap — the soft cap exists to keep users away from the lossy
  /// regime entirely.
  full,
}

@immutable
class MeshCanvasTransmissionStatus {
  /// Rows currently in `pending_op` for this canvas.
  final int pendingCount;

  /// Age (milliseconds since epoch) of the oldest queued row. `null`
  /// when the queue is empty.
  final int? oldestPendingAtMs;

  /// Next scheduled drain attempt across the canvas's queued rows.
  /// `null` when the queue is empty or every row is ready now.
  final int? nextAttemptAtMs;

  /// Canvas governor has insufficient headroom for even a single
  /// minimal paint frame (24 bytes — the `paint` action size).
  final bool isCanvasBudgetCooling;

  /// SIP rate limiter recently refused a canvas frame (within the
  /// last 5 seconds). Derived in the view model from the send
  /// coordinator's `lastSipDenialAtMs`.
  final bool isSipBudgetCooling;

  /// Whether the user is allowed to enqueue more mesh paints. Mirrors
  /// `severity != full`. Exposed as its own field so paint handlers
  /// don't have to know the severity rules.
  final bool canPaint;

  /// Derived severity bucket. See [MeshCanvasTransmissionSeverity].
  final MeshCanvasTransmissionSeverity severity;

  const MeshCanvasTransmissionStatus({
    required this.pendingCount,
    required this.oldestPendingAtMs,
    required this.nextAttemptAtMs,
    required this.isCanvasBudgetCooling,
    required this.isSipBudgetCooling,
    required this.canPaint,
    required this.severity,
  });

  /// Canonical idle state — used for local-scope viewers, empty
  /// queues, and fallback while async providers are loading.
  static const MeshCanvasTransmissionStatus idle = MeshCanvasTransmissionStatus(
    pendingCount: 0,
    oldestPendingAtMs: null,
    nextAttemptAtMs: null,
    isCanvasBudgetCooling: false,
    isSipBudgetCooling: false,
    canPaint: true,
    severity: MeshCanvasTransmissionSeverity.idle,
  );

  /// UX soft cap. Blocking new paint taps at this many pending rows
  /// keeps the user well away from the lossy hard cap (256) so they
  /// never silently lose a paint. Documented in
  /// CANVAS_TRANSMISSION_STATUS_V0_1.md §2.1.
  static const int softQueueCap = 32;

  /// Minimum canvas-payload bytes the governor needs to accept one
  /// single-paint frame (action 0x0001). If headroom falls below this
  /// the governor is "cooling" — nothing can move until the window
  /// decays.
  static const int minPaintBytes = 24;

  /// SIP cooling decay window. `lastSipDenialAtMs` is treated as
  /// "still cooling" inside this window; outside it the SIP flag
  /// clears even before the next send attempt actually succeeds.
  static const Duration sipCoolingWindow = Duration(seconds: 5);

  /// Derive a status snapshot from the underlying inputs. Centralised
  /// here so the view model, tests, and any future debug surface all
  /// compute severity identically.
  factory MeshCanvasTransmissionStatus.derive({
    required int pendingCount,
    required int? oldestPendingAtMs,
    required int? nextAttemptAtMs,
    required int governorRemainingBytes,
    required int? lastSipDenialAtMs,
    required int nowMs,
  }) {
    final isCanvasBudgetCooling = governorRemainingBytes < minPaintBytes;
    final isSipBudgetCooling =
        lastSipDenialAtMs != null &&
        (nowMs - lastSipDenialAtMs) < sipCoolingWindow.inMilliseconds;

    final MeshCanvasTransmissionSeverity severity;
    if (pendingCount >= softQueueCap) {
      severity = MeshCanvasTransmissionSeverity.full;
    } else if (isCanvasBudgetCooling || isSipBudgetCooling) {
      severity = MeshCanvasTransmissionSeverity.cooling;
    } else if (pendingCount > 0) {
      severity = MeshCanvasTransmissionSeverity.queued;
    } else {
      severity = MeshCanvasTransmissionSeverity.idle;
    }

    return MeshCanvasTransmissionStatus(
      pendingCount: pendingCount,
      oldestPendingAtMs: oldestPendingAtMs,
      nextAttemptAtMs: nextAttemptAtMs,
      isCanvasBudgetCooling: isCanvasBudgetCooling,
      isSipBudgetCooling: isSipBudgetCooling,
      canPaint: severity != MeshCanvasTransmissionSeverity.full,
      severity: severity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MeshCanvasTransmissionStatus &&
        other.pendingCount == pendingCount &&
        other.oldestPendingAtMs == oldestPendingAtMs &&
        other.nextAttemptAtMs == nextAttemptAtMs &&
        other.isCanvasBudgetCooling == isCanvasBudgetCooling &&
        other.isSipBudgetCooling == isSipBudgetCooling &&
        other.canPaint == canPaint &&
        other.severity == severity;
  }

  @override
  int get hashCode => Object.hash(
    pendingCount,
    oldestPendingAtMs,
    nextAttemptAtMs,
    isCanvasBudgetCooling,
    isSipBudgetCooling,
    canPaint,
    severity,
  );

  @override
  String toString() =>
      'MeshCanvasTransmissionStatus(severity: $severity, '
      'pending: $pendingCount, '
      'canvasCooling: $isCanvasBudgetCooling, '
      'sipCooling: $isSipBudgetCooling)';
}

/// Stats snapshot returned by the repository in a single round trip.
/// Powers the view model's pending-side derivation without forcing
/// three separate SQL queries.
@immutable
class CanvasPendingStats {
  /// Number of rows currently in `pending_op` for the canvas.
  final int count;

  /// `created_at_ms` of the oldest row. `null` when count is zero.
  final int? oldestCreatedAtMs;

  /// `next_attempt_at_ms` of the earliest-due row. `null` when count
  /// is zero.
  final int? nextAttemptAtMs;

  const CanvasPendingStats({
    required this.count,
    required this.oldestCreatedAtMs,
    required this.nextAttemptAtMs,
  });

  static const CanvasPendingStats empty = CanvasPendingStats(
    count: 0,
    oldestCreatedAtMs: null,
    nextAttemptAtMs: null,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CanvasPendingStats &&
        other.count == count &&
        other.oldestCreatedAtMs == oldestCreatedAtMs &&
        other.nextAttemptAtMs == nextAttemptAtMs;
  }

  @override
  int get hashCode => Object.hash(count, oldestCreatedAtMs, nextAttemptAtMs);

  @override
  String toString() =>
      'CanvasPendingStats(count: $count, oldest: $oldestCreatedAtMs, '
      'nextAttempt: $nextAttemptAtMs)';
}
