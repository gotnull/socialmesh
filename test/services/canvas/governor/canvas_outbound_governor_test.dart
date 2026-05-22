// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';

/// Deterministic monotonic clock for sliding-window assertions. The
/// clock only moves when the test explicitly advances it; `now()`
/// reads are otherwise constant.
class _FakeClock {
  int _ms;
  _FakeClock(this._ms);
  int now() => _ms;
  void advance(Duration d) {
    _ms += d.inMilliseconds;
  }
}

void main() {
  group('CanvasOutboundGovernor — basic budget', () {
    test('starts with full remaining budget', () {
      final g = CanvasOutboundGovernor();
      expect(g.remainingBytes, CanvasOutboundGovernor.budgetBytes);
      expect(g.budgetBytesPerWindow, CanvasOutboundGovernor.budgetBytes);
    });

    test('canSend allows up to 250 bytes in 60 s', () {
      final clock = _FakeClock(0);
      final g = CanvasOutboundGovernor(nowMs: clock.now);
      g.recordSend(100);
      g.recordSend(100);
      expect(g.remainingBytes, 50);
      expect(g.canSend(50), isTrue);
      expect(g.canSend(51), isFalse);
    });

    test('recordSend up to exactly 250 leaves headroom=0', () {
      final clock = _FakeClock(0);
      final g = CanvasOutboundGovernor(nowMs: clock.now);
      g.recordSend(250);
      expect(g.remainingBytes, 0);
      expect(g.canSend(1), isFalse);
    });

    test('canSend rejects bytes > 250 even on an empty window', () {
      final g = CanvasOutboundGovernor();
      expect(g.canSend(251), isFalse);
      expect(g.canSend(CanvasOutboundGovernor.budgetBytes + 1), isFalse);
    });

    test('canSend rejects zero and negative byte counts', () {
      final g = CanvasOutboundGovernor();
      expect(g.canSend(0), isFalse);
      expect(g.canSend(-1), isFalse);
    });
  });

  group('CanvasOutboundGovernor — sliding window', () {
    test('events outside the trailing 60 s are pruned', () {
      final clock = _FakeClock(0);
      final g = CanvasOutboundGovernor(nowMs: clock.now);

      // Two sends at t=0 consume 200 bytes.
      g.recordSend(100);
      g.recordSend(100);
      expect(g.remainingBytes, 50);
      expect(g.debugEventCount, 2);

      // Advance the clock past the window end (the prune condition is
      // `atMs <= cutoff`, so going past the window's exact end frees
      // entries logged at the start).
      clock.advance(const Duration(seconds: 61));
      expect(g.remainingBytes, CanvasOutboundGovernor.budgetBytes);
      expect(g.debugEventCount, 0);
    });

    test('partial expiry frees proportional headroom', () {
      final clock = _FakeClock(0);
      final g = CanvasOutboundGovernor(nowMs: clock.now);

      g.recordSend(100); // t = 0
      clock.advance(const Duration(seconds: 30));
      g.recordSend(100); // t = 30 s
      expect(g.remainingBytes, 50);

      // 31 s later the first event has aged out; second still in window.
      clock.advance(const Duration(seconds: 31));
      expect(g.remainingBytes, 150);
      expect(g.debugEventCount, 1);
    });
  });

  group('CanvasOutboundGovernor — tryConsume atomicity', () {
    test('tryConsume returns true and charges budget on success', () {
      final clock = _FakeClock(0);
      final g = CanvasOutboundGovernor(nowMs: clock.now);
      expect(g.tryConsume(100), isTrue);
      expect(g.remainingBytes, 150);
    });

    test('tryConsume returns false without charging on denial', () {
      final clock = _FakeClock(0);
      final g = CanvasOutboundGovernor(nowMs: clock.now);
      g.recordSend(200);
      expect(g.tryConsume(100), isFalse);
      expect(g.remainingBytes, 50);
    });

    test('tryConsume rejects invalid byte counts', () {
      final g = CanvasOutboundGovernor();
      expect(g.tryConsume(0), isFalse);
      expect(g.tryConsume(-5), isFalse);
      expect(g.tryConsume(CanvasOutboundGovernor.budgetBytes + 1), isFalse);
      expect(g.remainingBytes, CanvasOutboundGovernor.budgetBytes);
    });
  });

  group('CanvasOutboundGovernor — defensive recordSend', () {
    test('recordSend silently ignores invalid byte counts', () {
      final g = CanvasOutboundGovernor();
      g.recordSend(0);
      g.recordSend(-1);
      g.recordSend(CanvasOutboundGovernor.budgetBytes + 1);
      expect(g.debugEventCount, 0);
      expect(g.remainingBytes, CanvasOutboundGovernor.budgetBytes);
    });
  });
}
