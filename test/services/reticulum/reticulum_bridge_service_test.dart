// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/reticulum/reticulum_bridge_service.dart';
import 'package:socialmesh/services/reticulum/reticulum_tcp_framing.dart';

class _FakeBridgeSocket implements BridgeSocket {
  _FakeBridgeSocket();

  final List<Uint8List> writes = <Uint8List>[];
  final Completer<void> _done = Completer<void>();

  Object? errorOnNextWrite;
  Completer<void>? gate;
  bool closed = false;

  @override
  Future<void> write(List<int> bytes) async {
    if (closed) {
      throw StateError('socket closed');
    }
    if (errorOnNextWrite != null) {
      final e = errorOnNextWrite!;
      errorOnNextWrite = null;
      throw e;
    }
    if (gate != null) {
      await gate!.future;
    }
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

class _FakeFactory {
  _FakeFactory();

  final Queue<_FactoryResponse> responses = Queue<_FactoryResponse>();
  final List<({String host, int port})> attempts = [];

  Future<BridgeSocket> connect(String host, int port) async {
    attempts.add((host: host, port: port));
    if (responses.isEmpty) {
      throw StateError('no fake response queued for $host:$port');
    }
    final next = responses.removeFirst();
    if (next.error != null) throw next.error!;
    return next.socket!;
  }

  void queueSocket(BridgeSocket s) =>
      responses.add(_FactoryResponse(socket: s));
  void queueError(Object e) => responses.add(_FactoryResponse(error: e));
}

class _FactoryResponse {
  _FactoryResponse({this.socket, this.error});
  final BridgeSocket? socket;
  final Object? error;
}

/// Cycling-sequence Random for deterministic jitter assertions.
class _SeqRandom implements math.Random {
  _SeqRandom(this._sequence);
  final List<int> _sequence;
  int _i = 0;

  @override
  int nextInt(int max) {
    final v = _sequence[_i++ % _sequence.length];
    return v % max;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.0;
}

Uint8List _body(int seed) =>
    Uint8List.fromList(List<int>.generate(40, (i) => (seed + i) & 0xFF));

void main() {
  group('ReticulumBridgeService — initial state', () {
    test('starts disconnected with empty counters', () {
      final svc = ReticulumBridgeService(socketFactory: _FakeFactory().connect);
      expect(svc.status.kind, ReticulumBridgeStatusKind.disconnected);
      expect(svc.counters.forwarded, 0);
      expect(svc.counters.connectAttempts, 0);
      expect(svc.queueDepth, 0);
      expect(svc.queueCapacity, kReticulumBridgeQueueDepth);
      expect(svc.totalUptime, Duration.zero);
      expect(svc.currentSessionUptime, Duration.zero);
    });

    test('sendFrame while disconnected drops as droppedNoConnection', () {
      final svc = ReticulumBridgeService(socketFactory: _FakeFactory().connect);
      expect(svc.sendFrame(_body(0)), isFalse);
      expect(svc.counters.droppedNoConnection, 1);
      expect(svc.counters.forwarded, 0);
      expect(svc.queueDepth, 0);
    });
  });

  group('ReticulumBridgeService — connect lifecycle', () {
    test('emits connecting → connected on success', () async {
      final factory = _FakeFactory();
      factory.queueSocket(_FakeBridgeSocket());
      final svc = ReticulumBridgeService(socketFactory: factory.connect);

      final captured = <ReticulumBridgeStatusKind>[];
      final sub = svc.statusStream.listen((s) => captured.add(s.kind));
      await svc.connect('127.0.0.1', 4242);
      // Yield once for the broadcast stream to deliver pending events.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(captured, [
        ReticulumBridgeStatusKind.connecting,
        ReticulumBridgeStatusKind.connected,
      ]);
      expect(svc.status.kind, ReticulumBridgeStatusKind.connected);
      expect(svc.counters.connectAttempts, 1);
      expect(svc.counters.connectErrors, 0);
      expect(factory.attempts.single, (host: '127.0.0.1', port: 4242));
    });

    test(
      'connect is idempotent while already connecting / connected',
      () async {
        final factory = _FakeFactory();
        factory.queueSocket(_FakeBridgeSocket());
        final svc = ReticulumBridgeService(socketFactory: factory.connect);
        await svc.connect('h', 1);
        await svc.connect('h', 1);
        expect(svc.counters.connectAttempts, 1);
      },
    );

    test(
      'disconnect transitions back to disconnected and stays there',
      () async {
        final factory = _FakeFactory();
        final socket = _FakeBridgeSocket();
        factory.queueSocket(socket);
        final svc = ReticulumBridgeService(socketFactory: factory.connect);
        await svc.connect('h', 1);
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);
        await svc.disconnect();
        expect(svc.status.kind, ReticulumBridgeStatusKind.disconnected);
        expect(socket.closed, isTrue);
      },
    );
  });

  group('ReticulumBridgeService — sending frames', () {
    test('sendFrame writes HDLC-encoded bytes to the socket', () async {
      final factory = _FakeFactory();
      final socket = _FakeBridgeSocket();
      factory.queueSocket(socket);
      final svc = ReticulumBridgeService(socketFactory: factory.connect);
      await svc.connect('h', 1);

      final body = _body(0);
      expect(svc.sendFrame(body), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(socket.writes, hasLength(1));
      expect(socket.writes.single, ReticulumTcpFraming.encodeFrame(body));
      expect(svc.counters.forwarded, 1);
    });
  });

  group('ReticulumBridgeService — bounded queue (drop-newest)', () {
    test(
      '33rd send drops while drain is gated; first 32 flush after release',
      () async {
        final factory = _FakeFactory();
        final socket = _FakeBridgeSocket()..gate = Completer<void>();
        factory.queueSocket(socket);
        final svc = ReticulumBridgeService(socketFactory: factory.connect);
        await svc.connect('h', 1);

        // Send 32 frames; drain pulls the first synchronously and is
        // pinned awaiting the gated write. The remaining 31 sit in
        // the queue. With the in-flight slot included, the queue
        // accounting is now full at 31 + 1 in-flight = 32.
        for (var i = 0; i < 32; i++) {
          expect(svc.sendFrame(_body(i)), isTrue, reason: 'send $i');
        }
        await Future<void>.delayed(Duration.zero);
        expect(svc.queueDepth, 31);

        // The 33rd attempt finds the queue at capacity and drops.
        expect(svc.sendFrame(_body(99)), isFalse);
        expect(svc.counters.droppedBackpressure, 1);

        // Release the gate; remaining frames flush in order.
        socket.gate!.complete();
        socket.gate = null;
        // Drain the rest. Several microtask turns are needed because
        // each write is its own awaited future.
        for (var i = 0; i < 64; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(svc.counters.forwarded, 32);
        expect(svc.counters.droppedBackpressure, 1);
        expect(socket.writes, hasLength(32));
      },
    );
  });

  group('ReticulumBridgeService — write errors', () {
    test(
      'write error increments droppedFramingError and fires error status',
      () async {
        final factory = _FakeFactory();
        final socket = _FakeBridgeSocket()
          ..errorOnNextWrite = Exception('broken pipe');
        factory.queueSocket(socket);
        // No reconnect target queued — so the auto-reconnect attempt
        // will hit "no fake response queued" and emit a connect-error
        // status. We don't care about the second outcome; we care that
        // status traversed `error` after the write failure.
        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          backoffStart: const Duration(milliseconds: 100),
          backoffCap: const Duration(milliseconds: 100),
          random: _SeqRandom([1 << 30]),
        );

        final captured = <ReticulumBridgeStatusKind>[];
        svc.statusStream.listen((s) => captured.add(s.kind));

        await svc.connect('h', 1);
        expect(svc.sendFrame(_body(0)), isTrue);
        // Pump enough microtasks for the write to fire, fail, and
        // teardown to set status to error.
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(svc.counters.droppedFramingError, 1);
        expect(svc.counters.forwarded, 0);
        expect(captured, contains(ReticulumBridgeStatusKind.error));
      },
    );
  });

  group('ReticulumBridgeService — auto-reconnect', () {
    test('peer close triggers reconnect after backoff', () {
      fakeAsync((async) {
        final factory = _FakeFactory();
        final firstSocket = _FakeBridgeSocket();
        final secondSocket = _FakeBridgeSocket();
        factory.queueSocket(firstSocket);
        factory.queueSocket(secondSocket);

        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          random: _SeqRandom([500]),
        );
        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);

        firstSocket.simulateRemoteClose();
        async.flushMicrotasks();
        expect(svc.status.kind, ReticulumBridgeStatusKind.error);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);
        expect(factory.attempts, hasLength(2));
        expect(svc.counters.connectAttempts, 2);
      });
    });

    test('subsequent send works after auto-reconnect', () {
      fakeAsync((async) {
        final factory = _FakeFactory();
        final firstSocket = _FakeBridgeSocket();
        final secondSocket = _FakeBridgeSocket();
        factory.queueSocket(firstSocket);
        factory.queueSocket(secondSocket);

        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          random: _SeqRandom([0]),
        );
        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        firstSocket.simulateRemoteClose();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);

        final body = _body(7);
        expect(svc.sendFrame(body), isTrue);
        async.flushMicrotasks();
        expect(secondSocket.writes, hasLength(1));
        expect(
          secondSocket.writes.single,
          ReticulumTcpFraming.encodeFrame(body),
        );
      });
    });
  });

  group('ReticulumBridgeService — backoff schedule', () {
    test('exponential ceilings 1s, 2s, 4s, …, 60s, then capped', () {
      // Use a Random that always returns its argument minus 1, so
      // each `nextInt(ceiling+1)` yields exactly the ceiling — gives
      // us a deterministic worst-case jitter for ceiling assertions.
      final factory = _FakeFactory();
      // Queue 8 connect errors so each retry hits a new failure.
      for (var i = 0; i < 8; i++) {
        factory.queueError(StateError('fail $i'));
      }
      final svc = ReticulumBridgeService(
        socketFactory: factory.connect,
        random: _MaxOutRandom(),
      );

      final actualCeilings = <int>[];
      final expectedCeilings = <int>[
        1000,
        2000,
        4000,
        8000,
        16000,
        32000,
        60000,
        60000,
      ];

      fakeAsync((async) {
        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        for (var i = 0; i < expectedCeilings.length; i++) {
          actualCeilings.add(svc.lastBackoffDelay!.inMilliseconds);
          // Elapse exactly enough to fire ONE retry; not 60 s, which
          // would let the next retry chain in too.
          async.elapse(svc.lastBackoffDelay! + const Duration(milliseconds: 1));
          async.flushMicrotasks();
        }
      });

      // With _MaxOutRandom, lastBackoffDelay equals the ceiling for
      // each attempt.
      expect(actualCeilings, expectedCeilings);
    });

    test('successful connect resets backoff attempt counter', () {
      fakeAsync((async) {
        final factory = _FakeFactory();
        factory.queueError(StateError('first fail'));
        final secondSocket = _FakeBridgeSocket();
        factory.queueSocket(secondSocket);

        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          random: _MaxOutRandom(),
        );

        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        // After the first failure, backoff attempt counter has
        // advanced past 0.
        expect(svc.currentBackoffAttempt, greaterThan(0));

        async.elapse(svc.lastBackoffDelay! + const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);
        // Successful connect must reset the exponent.
        expect(svc.currentBackoffAttempt, 0);
      });
    });
  });

  group('ReticulumBridgeService — uptime accumulation', () {
    test('totalUptime grows across reconnects', () {
      fakeAsync((async) {
        final t0 = DateTime.utc(2026, 1, 1);
        var clock = t0;
        final factory = _FakeFactory();
        final firstSocket = _FakeBridgeSocket();
        final secondSocket = _FakeBridgeSocket();
        factory.queueSocket(firstSocket);
        factory.queueSocket(secondSocket);

        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          random: _SeqRandom([0]),
          clock: () => clock,
        );

        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        clock = clock.add(const Duration(seconds: 5));
        firstSocket.simulateRemoteClose();
        async.flushMicrotasks();

        expect(svc.totalUptime, const Duration(seconds: 5));
        expect(svc.currentSessionUptime, Duration.zero);

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);

        clock = clock.add(const Duration(seconds: 7));
        expect(svc.totalUptime, const Duration(seconds: 12));
        expect(svc.currentSessionUptime, const Duration(seconds: 7));
      });
    });
  });

  group('ReticulumBridgeService — auto-disable after repeated failures', () {
    test(
      'flips autoDisabled true after threshold consecutive errors and stops retrying',
      () {
        fakeAsync((async) {
          final factory = _FakeFactory();
          // Threshold of 3 to keep the test small.
          for (var i = 0; i < 5; i++) {
            factory.queueError(StateError('fail $i'));
          }
          final svc = ReticulumBridgeService(
            socketFactory: factory.connect,
            random: _MaxOutRandom(),
            autoDisableThreshold: 3,
          );

          unawaited(svc.connect('h', 1));
          async.flushMicrotasks();
          // Drive 3 retries — each elapse fires exactly one retry.
          for (var i = 0; i < 2; i++) {
            async.elapse(
              svc.lastBackoffDelay! + const Duration(milliseconds: 1),
            );
            async.flushMicrotasks();
          }

          expect(svc.autoDisabled, isTrue);
          expect(svc.consecutiveConnectErrors, 3);
          expect(svc.counters.connectAttempts, 3);

          // Subsequent time advances must NOT trigger a 4th attempt.
          async.elapse(const Duration(seconds: 120));
          async.flushMicrotasks();
          expect(svc.counters.connectAttempts, 3);
          // Only 3 errors were dequeued from the factory; 2 still queued.
          expect(factory.responses.length, 2);
        });
      },
    );

    test('successful connect resets consecutiveConnectErrors', () {
      fakeAsync((async) {
        final factory = _FakeFactory();
        factory.queueError(StateError('fail once'));
        factory.queueSocket(_FakeBridgeSocket());

        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          random: _MaxOutRandom(),
          autoDisableThreshold: 5,
        );

        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        expect(svc.consecutiveConnectErrors, 1);

        async.elapse(svc.lastBackoffDelay! + const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);
        expect(svc.consecutiveConnectErrors, 0);
        expect(svc.autoDisabled, isFalse);
      });
    });

    test('clearAutoDisable re-engages connection attempts', () {
      fakeAsync((async) {
        final factory = _FakeFactory();
        factory.queueError(StateError('first'));
        factory.queueError(StateError('second'));
        factory.queueSocket(_FakeBridgeSocket());

        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          random: _MaxOutRandom(),
          autoDisableThreshold: 2,
        );

        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        async.elapse(svc.lastBackoffDelay! + const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(svc.autoDisabled, isTrue);

        unawaited(svc.clearAutoDisable());
        async.flushMicrotasks();

        expect(svc.autoDisabled, isFalse);
        expect(svc.status.kind, ReticulumBridgeStatusKind.connected);
        expect(svc.consecutiveConnectErrors, 0);
      });
    });
  });

  group('ReticulumBridgeService — last forward timestamp', () {
    test('lastForwardAt is null until first successful forward', () async {
      final factory = _FakeFactory();
      final svc = ReticulumBridgeService(socketFactory: factory.connect);
      expect(svc.lastForwardAt, isNull);
      // Drop a frame while disconnected — must NOT update timestamp.
      svc.sendFrame(_body(0));
      expect(svc.lastForwardAt, isNull);
    });

    test('lastForwardAt advances on each successful forward', () async {
      final t0 = DateTime.utc(2026, 1, 1);
      var clock = t0;
      final factory = _FakeFactory();
      factory.queueSocket(_FakeBridgeSocket());
      final svc = ReticulumBridgeService(
        socketFactory: factory.connect,
        clock: () => clock,
      );

      await svc.connect('h', 1);
      svc.sendFrame(_body(0));
      await Future<void>.delayed(Duration.zero);
      expect(svc.lastForwardAt, t0);

      clock = clock.add(const Duration(seconds: 5));
      svc.sendFrame(_body(1));
      await Future<void>.delayed(Duration.zero);
      expect(svc.lastForwardAt, t0.add(const Duration(seconds: 5)));
    });
  });

  group('ReticulumBridgeService — session log ring buffer', () {
    test('logs connect / connected lifecycle on success', () async {
      final factory = _FakeFactory();
      factory.queueSocket(_FakeBridgeSocket());
      final svc = ReticulumBridgeService(socketFactory: factory.connect);
      await svc.connect('h', 1);
      final messages = svc.logEntries.map((e) => e.message).toList();
      expect(messages, hasLength(2));
      expect(messages[0], contains('Connecting to tcp://h:1'));
      expect(messages[1], contains('Connected to tcp://h:1'));
      expect(svc.logEntries[0].level, ReticulumBridgeLogLevel.info);
      expect(svc.logEntries[1].level, ReticulumBridgeLogLevel.info);
    });

    test('logs error on connect failure with attempt counter', () {
      fakeAsync((async) {
        final factory = _FakeFactory();
        factory.queueError(StateError('boom'));
        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          random: _MaxOutRandom(),
          autoDisableThreshold: 5,
        );
        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        final errLog = svc.logEntries.firstWhere(
          (e) => e.level == ReticulumBridgeLogLevel.error,
        );
        expect(errLog.message, contains('Connect failed (1/5)'));
        expect(errLog.message, contains('tcp://h:1'));
      });
    });

    test('ring buffer evicts oldest beyond logCapacity', () async {
      final factory = _FakeFactory();
      factory.queueSocket(_FakeBridgeSocket());
      // logCapacity=4 → after 5 lifecycle entries, oldest is evicted.
      final svc = ReticulumBridgeService(
        socketFactory: factory.connect,
        logCapacity: 4,
      );
      await svc.connect('h', 1);
      // Two entries so far. Fire frame writes — those don't log
      // (per design, frame-level traffic stays out of session log).
      // Force three more entries via repeated disconnect/connect.
      await svc.disconnect();
      // Need new sockets for the next two reconnects.
      factory.queueSocket(_FakeBridgeSocket());
      factory.queueSocket(_FakeBridgeSocket());
      await svc.connect('h', 1);
      await svc.disconnect();
      await svc.connect('h', 1);

      expect(svc.logEntries.length, 4);
      // First entry must NOT be the original "Connecting to tcp://h:1"
      // — it should have been evicted as the oldest.
      // (Both "Connecting" and "Connected" share the same prefix; we
      // assert via total length above plus presence of the latest.)
      expect(svc.logEntries.last.message, contains('Connected to tcp://h:1'));
    });
  });

  group('ReticulumBridgeService — nextRetryAt', () {
    test('exposes the deadline of the pending retry timer', () {
      fakeAsync((async) {
        final t0 = DateTime.utc(2026, 1, 1);
        var clock = t0;
        final factory = _FakeFactory();
        factory.queueError(StateError('boom'));
        final svc = ReticulumBridgeService(
          socketFactory: factory.connect,
          random: _MaxOutRandom(),
          clock: () => clock,
          autoDisableThreshold: 5,
        );

        unawaited(svc.connect('h', 1));
        async.flushMicrotasks();
        // First failure → ceiling 1000ms with _MaxOutRandom.
        expect(svc.nextRetryAt, isNotNull);
        expect(
          svc.nextRetryAt!.difference(t0),
          const Duration(milliseconds: 1000),
        );
      });
    });

    test('clears nextRetryAt on successful connect', () async {
      final factory = _FakeFactory();
      factory.queueSocket(_FakeBridgeSocket());
      final svc = ReticulumBridgeService(socketFactory: factory.connect);
      await svc.connect('h', 1);
      expect(svc.nextRetryAt, isNull);
    });
  });
}

/// Always returns `max - 1` from `nextInt(max)` — the worst-case
/// jitter so tests can assert ceiling values exactly.
class _MaxOutRandom implements math.Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.0;
}
