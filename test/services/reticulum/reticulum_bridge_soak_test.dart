// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Synthetic soak harness for the hardened TCP bridge service.
// Drives four time-compressed scenarios against the service with
// `package:fake_async`, asserting the cross-cutting success criteria:
//
//   * no leaked sockets — every fake socket the factory minted is
//     closed by service teardown (or was the live one at the time)
//   * queue returns to 0 — no frames stuck after a send burst
//   * counters monotonically sane (no rollover, drops accounted for)
//   * retry / auto-disable behave visibly (counters + autoDisabled
//     reach the expected end state)
//
// Scenarios 5–7 (app foreground/background, BLE reconnect, RF loss)
// require real hardware and are documented as a manual procedure in
// `docs/protocol/RETICULUM_BRIDGE_SOAK_RESULTS.md`.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/reticulum/reticulum_bridge_service.dart';

class _SoakSocket implements BridgeSocket {
  _SoakSocket(this.id);
  final int id;
  final List<Uint8List> writes = <Uint8List>[];
  final Completer<void> _done = Completer<void>();
  bool closed = false;

  @override
  Future<void> write(List<int> bytes) async {
    if (closed) throw StateError('soak socket $id closed');
    writes.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async {
    if (!closed) {
      closed = true;
      if (!_done.isCompleted) _done.complete();
    }
  }

  void simulateRemoteClose() {
    if (!closed) {
      closed = true;
      if (!_done.isCompleted) _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;
}

/// Tracks every socket minted by the factory so the harness can
/// assert no leaks at the end of a scenario.
class _SoakFactory {
  _SoakFactory();
  final Queue<_Resp> responses = Queue<_Resp>();
  final List<_SoakSocket> minted = [];
  int _nextId = 0;

  Future<BridgeSocket> connect(String host, int port) async {
    if (responses.isEmpty) {
      throw StateError('no fake response queued for $host:$port');
    }
    final r = responses.removeFirst();
    if (r.error != null) throw r.error!;
    final s = _SoakSocket(_nextId++);
    minted.add(s);
    return s;
  }

  void queueSocket() => responses.add(_Resp());
  void queueError(Object e) => responses.add(_Resp(error: e));

  /// Number of sockets that are currently NOT closed. After dispose,
  /// must always be 0 — anything else is a leak.
  int get openSocketCount => minted.where((s) => !s.closed).length;
}

class _Resp {
  _Resp({this.error});
  final Object? error;
}

class _FixedRandom implements math.Random {
  _FixedRandom(this.value);
  final int value;
  @override
  int nextInt(int max) => value % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.0;
}

Uint8List _body(int seed) =>
    Uint8List.fromList(List<int>.generate(40, (i) => (seed + i) & 0xFF));

void main() {
  group('Soak — Scenario 1: 15 minutes idle connected', () {
    test('service stays connected, queue stays empty, no socket leaks', () {
      fakeAsync((async) {
        final factory = _SoakFactory();
        factory.queueSocket();
        final svc = ReticulumBridgeService(socketFactory: factory.connect);

        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);

        // Time-compress 15 minutes of idle.
        async.elapse(const Duration(minutes: 15));
        async.flushMicrotasks();

        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);
        expect(svc.queueDepth, 0);
        expect(svc.counters.forwarded, 0);
        expect(svc.counters.connectAttempts, 1);
        expect(svc.counters.connectErrors, 0);
        expect(svc.consecutiveConnectErrors, 0);
        expect(svc.autoDisabled, isFalse);

        // Single live socket, no leaks.
        expect(factory.minted, hasLength(1));
        expect(factory.openSocketCount, 1);

        unawaited(svc.dispose());
        async.flushMicrotasks();
        // After dispose, every minted socket must be closed.
        expect(factory.openSocketCount, 0);
      });
    });
  });

  group('Soak — Scenario 2: 30 minutes intermittent announces', () {
    test('one frame per minute for 30 minutes — all forwarded, queue settles, '
        'no leaks', () {
      fakeAsync((async) {
        final factory = _SoakFactory();
        factory.queueSocket();
        final svc = ReticulumBridgeService(socketFactory: factory.connect);

        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();

        for (var i = 0; i < 30; i++) {
          expect(svc.sendFrame(_body(i)), isTrue, reason: 'frame $i');
          async.flushMicrotasks();
          expect(svc.queueDepth, 0, reason: 'after frame $i');
          async.elapse(const Duration(minutes: 1));
        }
        async.flushMicrotasks();

        expect(svc.counters.forwarded, 30);
        expect(svc.counters.droppedNoConnection, 0);
        expect(svc.counters.droppedBackpressure, 0);
        expect(svc.counters.droppedFramingError, 0);
        expect(svc.queueDepth, 0);
        expect(svc.lastForwardAt, isNotNull);
        expect(factory.minted, hasLength(1));

        unawaited(svc.dispose());
        async.flushMicrotasks();
        expect(factory.openSocketCount, 0);
      });
    });
  });

  group('Soak — Scenario 3: bad host (refused connection)', () {
    test(
      'auto-disable latches at threshold, no infinite retry, no socket leaks',
      () {
        fakeAsync((async) {
          final factory = _SoakFactory();
          // Queue MANY errors so the test would fail if retry kept
          // going past the threshold.
          for (var i = 0; i < 100; i++) {
            factory.queueError(StateError('refused'));
          }
          final svc = ReticulumBridgeService(
            socketFactory: factory.connect,
            random: _FixedRandom(0),
            autoDisableThreshold: 5,
          );

          unawaited(svc.connect('badhost', 9999));
          async.flushMicrotasks();
          // Drive 4 retries (threshold = 5 → first attempt + 4 retries).
          for (var i = 0; i < 4; i++) {
            async.elapse(
              svc.lastBackoffDelay! + const Duration(milliseconds: 1),
            );
            async.flushMicrotasks();
          }

          expect(svc.autoDisabled, isTrue);
          expect(svc.consecutiveConnectErrors, 5);
          expect(svc.counters.connectAttempts, 5);
          expect(svc.counters.connectErrors, 5);

          // Time advances 1 hour — must NOT trigger any further attempts.
          async.elapse(const Duration(hours: 1));
          async.flushMicrotasks();
          expect(svc.counters.connectAttempts, 5);

          // No sockets were ever opened.
          expect(factory.minted, isEmpty);

          // The session log carries the auto-disable signal so
          // copy-diagnostics surfaces it usefully.
          final logMessages = svc.logEntries.map((e) => e.message).toList();
          expect(logMessages.any((m) => m.contains('Auto-disabled')), isTrue);

          unawaited(svc.dispose());
          async.flushMicrotasks();
          expect(factory.openSocketCount, 0);
        });
      },
    );
  });

  group('Soak — Scenario 4: rnsd restart while connected', () {
    test(
      'peer close → reconnect → forwarding resumes; no frames double-counted',
      () {
        fakeAsync((async) {
          final factory = _SoakFactory();
          factory.queueSocket();
          factory.queueSocket();
          final svc = ReticulumBridgeService(
            socketFactory: factory.connect,
            random: _FixedRandom(0),
          );

          unawaited(svc.connect('h', 1));
          async.flushMicrotasks();

          // Forward a few frames pre-restart.
          for (var i = 0; i < 5; i++) {
            svc.sendFrame(_body(i));
          }
          async.flushMicrotasks();
          expect(svc.counters.forwarded, 5);

          // Simulate rnsd restarting.
          factory.minted.first.simulateRemoteClose();
          async.flushMicrotasks();
          expect(svc.status.kind, ReticulumBridgeStatusKind.error);

          // Backoff fires; new socket comes up.
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();
          expect(svc.status.kind, ReticulumBridgeStatusKind.connected);
          expect(svc.consecutiveConnectErrors, 0);

          // Forward more frames post-restart.
          for (var i = 5; i < 10; i++) {
            svc.sendFrame(_body(i));
          }
          async.flushMicrotasks();
          expect(svc.counters.forwarded, 10);

          // First socket closed by remote, second alive.
          expect(factory.minted, hasLength(2));
          expect(factory.minted[0].closed, isTrue);
          expect(factory.minted[1].closed, isFalse);

          // No frames should have leaked into the closed socket
          // post-restart.
          expect(factory.minted[0].writes.length, 5);
          expect(factory.minted[1].writes.length, 5);

          unawaited(svc.dispose());
          async.flushMicrotasks();
          expect(factory.openSocketCount, 0);
        });
      },
    );
  });

  group('Soak — cross-cutting: diagnostics blob is meaningful', () {
    test(
      'session log captures connect / connected / lost / reconnect lifecycle',
      () {
        fakeAsync((async) {
          final factory = _SoakFactory();
          factory.queueSocket();
          factory.queueSocket();
          final svc = ReticulumBridgeService(
            socketFactory: factory.connect,
            random: _FixedRandom(0),
          );

          unawaited(svc.connect('h', 1));
          async.flushMicrotasks();
          factory.minted.first.simulateRemoteClose();
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          final messages = svc.logEntries.map((e) => e.message).toList();
          expect(
            messages.any((m) => m.contains('Connecting to tcp://h:1')),
            isTrue,
          );
          expect(
            messages.any((m) => m.contains('Connected to tcp://h:1')),
            isTrue,
          );
          expect(messages.any((m) => m.contains('Connection lost')), isTrue);
          // Reconnect produces a second connect/connected pair.
          expect(
            messages.where((m) => m.contains('Connected to tcp://h:1')).length,
            2,
          );

          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );
  });
}
