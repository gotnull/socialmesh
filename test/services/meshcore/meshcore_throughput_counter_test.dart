// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/meshcore_throughput_counter.dart';

void main() {
  group('MeshCoreThroughputCounter', () {
    test('starts at zero with no session', () {
      final c = MeshCoreThroughputCounter();
      expect(c.bytesTx, 0);
      expect(c.bytesRx, 0);
      expect(c.hasSession, isFalse);
      final s = c.snapshot();
      expect(s.bytesTx, 0);
      expect(s.bytesRx, 0);
      expect(s.txBytesPerSecond, 0);
      expect(s.rxBytesPerSecond, 0);
      expect(s.sessionSeconds, 0);
      expect(s.hasActivity, isFalse);
    });

    test('recordTx accumulates and starts session', () {
      var now = DateTime(2026, 5, 18, 12);
      final c = MeshCoreThroughputCounter(clock: () => now);
      c.recordTx(100);
      now = now.add(const Duration(seconds: 2));
      c.recordTx(50);
      expect(c.bytesTx, 150);
      expect(c.bytesRx, 0);
      expect(c.hasSession, isTrue);
      expect(c.snapshot().sessionSeconds, 2);
    });

    test('recordRx accumulates independently of TX', () {
      var now = DateTime(2026, 5, 18, 12);
      final c = MeshCoreThroughputCounter(clock: () => now);
      c.recordRx(200);
      now = now.add(const Duration(seconds: 3));
      c.recordRx(100);
      expect(c.bytesRx, 300);
      expect(c.bytesTx, 0);
      expect(c.snapshot().sessionSeconds, 3);
    });

    test('rolling rate over windowSeconds=10', () {
      var now = DateTime(2026, 5, 18, 12);
      final c = MeshCoreThroughputCounter(windowSeconds: 10, clock: () => now);
      // 100 B + 100 B + 100 B within 3 s = 300 B over 10 s window = 30 B/s
      c.recordTx(100);
      now = now.add(const Duration(seconds: 1));
      c.recordTx(100);
      now = now.add(const Duration(seconds: 1));
      c.recordTx(100);
      final s = c.snapshot();
      expect(s.txBytesPerSecond, closeTo(30.0, 0.001));
      expect(s.rxBytesPerSecond, 0);
      expect(s.bytesTx, 300);
    });

    test('samples outside window are evicted', () {
      var now = DateTime(2026, 5, 18, 12);
      final c = MeshCoreThroughputCounter(windowSeconds: 10, clock: () => now);
      c.recordTx(500); // at t=0
      now = now.add(const Duration(seconds: 15));
      c.recordTx(100); // at t=15, t=0 sample now outside window
      final s = c.snapshot();
      // Only the recent 100 B counts toward the rate: 100/10 = 10 B/s
      expect(s.txBytesPerSecond, closeTo(10.0, 0.001));
      // Cumulative total still 600 (lifetime counter not capped)
      expect(s.bytesTx, 600);
    });

    test('rate drops to zero after window of inactivity', () {
      var now = DateTime(2026, 5, 18, 12);
      final c = MeshCoreThroughputCounter(windowSeconds: 10, clock: () => now);
      c.recordTx(1000);
      now = now.add(const Duration(seconds: 11));
      final s = c.snapshot();
      expect(s.txBytesPerSecond, 0);
      expect(s.bytesTx, 1000); // lifetime preserved
    });

    test('TX and RX rates are independent', () {
      var now = DateTime(2026, 5, 18, 12);
      final c = MeshCoreThroughputCounter(windowSeconds: 10, clock: () => now);
      c.recordTx(200);
      c.recordRx(50);
      now = now.add(const Duration(seconds: 1));
      c.recordTx(200);
      final s = c.snapshot();
      expect(s.txBytesPerSecond, closeTo(40.0, 0.001));
      expect(s.rxBytesPerSecond, closeTo(5.0, 0.001));
    });

    test('reset clears session and counters', () {
      var now = DateTime(2026, 5, 18, 12);
      final c = MeshCoreThroughputCounter(clock: () => now);
      c.recordTx(100);
      c.recordRx(200);
      c.reset();
      expect(c.bytesTx, 0);
      expect(c.bytesRx, 0);
      expect(c.hasSession, isFalse);
      final s = c.snapshot();
      expect(s.bytesTx, 0);
      expect(s.bytesRx, 0);
      expect(s.txBytesPerSecond, 0);
      expect(s.rxBytesPerSecond, 0);
      expect(s.sessionSeconds, 0);
    });

    test('negative or zero byte counts are ignored', () {
      final c = MeshCoreThroughputCounter();
      c.recordTx(0);
      c.recordTx(-100);
      c.recordRx(0);
      c.recordRx(-50);
      expect(c.bytesTx, 0);
      expect(c.bytesRx, 0);
      expect(c.hasSession, isFalse);
    });

    test('hasActivity becomes true after first byte', () {
      final c = MeshCoreThroughputCounter();
      expect(c.snapshot().hasActivity, isFalse);
      c.recordTx(1);
      expect(c.snapshot().hasActivity, isTrue);
    });
  });
}
