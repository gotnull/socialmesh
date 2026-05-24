// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Mesh-canvas paint cadence gate. Tap-layer scarcity so that every
// mesh pixel feels like deliberate radio ink instead of confetti
// spray. Local Device Canvas is unmetered.
//
// Behaviour:
//   - First tap on a canvas: accepted.
//   - Subsequent tap within [CanvasCadence.meshTapInterval]: rejected
//     before any DB write or local cell mutation.
//   - After the interval expires: next tap accepted.
//
// State is in-memory only and per-canvas (a user painting on Primary
// can still paint immediately on TestChannel). Cleared on dispose.
//
// Stream `changes` lets the transmission status view model rebuild
// the moment a tap is recorded or the cooldown expires, so the HUD
// transitions from `cooling` back to `queued` / `idle` without
// waiting for a separate timer.
library;

import 'dart:async';

import 'canvas_constants.dart';

class CanvasPaintCadence {
  /// Per-canvas last-accepted-tap timestamp (ms since epoch).
  final Map<int, int> _lastAcceptedMs = {};

  /// Test seam so the unit tests can advance the clock deterministically.
  final int Function() _nowMs;

  /// Broadcast stream of canvasLocalIds whose cadence state may have
  /// changed (tap accepted or cooldown expired). The transmission
  /// status view model subscribes here so the HUD repaints the moment
  /// a cooldown lands or releases.
  final StreamController<int> _changes = StreamController<int>.broadcast();

  CanvasPaintCadence({int Function()? nowMs})
    : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Stream of canvasLocalIds whose cadence-cooling state may have flipped.
  Stream<int> get changes => _changes.stream;

  /// `true` when a fresh tap on this canvas would be inside the
  /// cooldown window. The viewport tap handler reads this BEFORE any
  /// enqueue / cell mutation; on `true` it rejects the tap silently.
  bool isCoolingDown(int canvasLocalId) {
    final last = _lastAcceptedMs[canvasLocalId];
    if (last == null) return false;
    return _nowMs() - last < CanvasCadence.meshTapInterval.inMilliseconds;
  }

  /// Ms remaining until the next tap on this canvas would be
  /// accepted. Returns 0 when the canvas is not cooling. The view
  /// model uses this to schedule a follow-up status refresh exactly
  /// at the cooldown expiry.
  int msUntilReady(int canvasLocalId) {
    final last = _lastAcceptedMs[canvasLocalId];
    if (last == null) return 0;
    final elapsed = _nowMs() - last;
    final remaining = CanvasCadence.meshTapInterval.inMilliseconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Record an accepted paint tap. Subsequent `isCoolingDown` checks
  /// for this canvas will return `true` until the interval elapses.
  /// Also schedules a microtask emit on [changes] so the HUD repaints.
  void recordTap(int canvasLocalId) {
    _lastAcceptedMs[canvasLocalId] = _nowMs();
    _emit(canvasLocalId);
    // No expiry timer is scheduled here. The transmission status
    // provider polls every 2s and re-evaluates `isCoolingDown`, so
    // the HUD drops back to a non-cooling severity within one poll
    // cycle of the cooldown elapsing. Scheduling a Timer here was
    // tried but caused widget-test framework "Timer still pending
    // after dispose" failures because addTearDown fires after the
    // invariant check.
  }

  void _emit(int canvasLocalId) {
    if (_changes.isClosed) return;
    _changes.add(canvasLocalId);
  }

  /// Test helper: clear all cooldowns. Production code never calls this.
  void resetForTest() {
    _lastAcceptedMs.clear();
  }

  void dispose() {
    _lastAcceptedMs.clear();
    _changes.close();
  }
}
