// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/reticulum_bridge_provider.dart';
import 'package:socialmesh/providers/reticulum_providers.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_frame.dart';
import 'package:socialmesh/services/reticulum/reticulum_bridge_service.dart';
import 'package:socialmesh/services/reticulum/reticulum_tcp_framing.dart';

class _FakeBridgeSocket implements BridgeSocket {
  _FakeBridgeSocket();
  final List<Uint8List> writes = <Uint8List>[];
  final Completer<void> _done = Completer<void>();
  bool closed = false;

  @override
  Future<void> write(List<int> bytes) async {
    if (closed) throw StateError('closed');
    writes.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async {
    if (!closed) {
      closed = true;
      if (!_done.isCompleted) _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;
}

class _FakeFactory {
  final Queue<_Resp> responses = Queue<_Resp>();
  final List<({String host, int port})> attempts = [];

  Future<BridgeSocket> connect(String host, int port) async {
    attempts.add((host: host, port: port));
    if (responses.isEmpty) {
      throw StateError('no fake response queued for $host:$port');
    }
    final r = responses.removeFirst();
    if (r.error != null) throw r.error!;
    return r.socket!;
  }

  void queueSocket(BridgeSocket s) => responses.add(_Resp(socket: s));
  void queueError(Object e) => responses.add(_Resp(error: e));
}

class _Resp {
  _Resp({this.socket, this.error});
  final BridgeSocket? socket;
  final Object? error;
}

ReticulumFrame _frame(int seed, {int len = 40}) {
  return ReticulumFrame(
    fromNode: 0xAABBCCDD,
    index: seed,
    fragmentCount: 1,
    body: Uint8List.fromList(List<int>.generate(len, (i) => (seed + i) & 0xFF)),
    firstSeenMs: 0,
    lastSeenMs: 0,
  );
}

ProviderContainer _makeContainer({
  required _FakeFactory factory,
  required Stream<ReticulumFrame> frames,
}) {
  final c = ProviderContainer(
    overrides: [
      reticulumBridgeSocketFactoryProvider.overrideWithValue(factory.connect),
      reticulumBridgeFrameSourceProvider.overrideWithValue(frames),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _pump([int turns = 6]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ReticulumBridgeProvider — initial state', () {
    test('exposes default host/port and disconnected status', () async {
      final factory = _FakeFactory();
      final ctrl = StreamController<ReticulumFrame>.broadcast();
      addTearDown(ctrl.close);
      final c = _makeContainer(factory: factory, frames: ctrl.stream);

      final state = await c.read(reticulumBridgeProvider.future);

      expect(state.host, kReticulumBridgeDefaultHost);
      expect(state.port, kReticulumBridgeDefaultPort);
      expect(state.enabled, isFalse);
      expect(state.status.kind, ReticulumBridgeStatusKind.disconnected);
      expect(state.counters.forwarded, 0);
      expect(state.queueDepth, 0);
      expect(state.queueCapacity, kReticulumBridgeQueueDepth);
      // Flags are all off → bridge must not have attempted to connect.
      expect(factory.attempts, isEmpty);
    });

    test('loads host/port persisted from previous run', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'reticulum.bridgeHost': '10.0.0.42',
        'reticulum.bridgePort': 1337,
      });
      final factory = _FakeFactory();
      final ctrl = StreamController<ReticulumFrame>.broadcast();
      addTearDown(ctrl.close);
      final c = _makeContainer(factory: factory, frames: ctrl.stream);

      final state = await c.read(reticulumBridgeProvider.future);
      expect(state.host, '10.0.0.42');
      expect(state.port, 1337);
    });
  });

  group('ReticulumBridgeProvider — gate logic', () {
    test('does not connect when bridgeEnabled is false', () async {
      final factory = _FakeFactory();
      final ctrl = StreamController<ReticulumFrame>.broadcast();
      addTearDown(ctrl.close);
      final c = _makeContainer(factory: factory, frames: ctrl.stream);

      await c.read(reticulumBridgeProvider.future);
      // reassembly on, bridge off
      await c.read(reticulumFlagsProvider.notifier).setReassemblyEnabled(true);
      await _pump();
      expect(factory.attempts, isEmpty);
    });

    test('does not connect when reassemblyEnabled is false', () async {
      final factory = _FakeFactory();
      final ctrl = StreamController<ReticulumFrame>.broadcast();
      addTearDown(ctrl.close);
      final c = _makeContainer(factory: factory, frames: ctrl.stream);

      await c.read(reticulumBridgeProvider.future);
      // bridge on, reassembly off
      await c.read(reticulumFlagsProvider.notifier).setBridgeEnabled(true);
      await _pump();
      expect(factory.attempts, isEmpty);
      // The provider state's `enabled` mirror should still update.
      expect(c.read(reticulumBridgeProvider).value!.enabled, isTrue);
    });

    test(
      'connects when both bridgeEnabled AND reassemblyEnabled are true',
      () async {
        final factory = _FakeFactory();
        factory.queueSocket(_FakeBridgeSocket());
        final ctrl = StreamController<ReticulumFrame>.broadcast();
        addTearDown(ctrl.close);
        final c = _makeContainer(factory: factory, frames: ctrl.stream);

        await c.read(reticulumBridgeProvider.future);
        await c
            .read(reticulumFlagsProvider.notifier)
            .setReassemblyEnabled(true);
        await c.read(reticulumFlagsProvider.notifier).setBridgeEnabled(true);
        await _pump();

        expect(factory.attempts, hasLength(1));
        expect(factory.attempts.single.host, kReticulumBridgeDefaultHost);
        expect(factory.attempts.single.port, kReticulumBridgeDefaultPort);
        expect(
          c.read(reticulumBridgeProvider).value!.status.kind,
          ReticulumBridgeStatusKind.connected,
        );
      },
    );

    test(
      'disconnects + stops forwarding when bridge flag flips false',
      () async {
        final factory = _FakeFactory();
        final socket = _FakeBridgeSocket();
        factory.queueSocket(socket);
        final ctrl = StreamController<ReticulumFrame>.broadcast();
        addTearDown(ctrl.close);
        final c = _makeContainer(factory: factory, frames: ctrl.stream);

        await c.read(reticulumBridgeProvider.future);
        await c
            .read(reticulumFlagsProvider.notifier)
            .setReassemblyEnabled(true);
        await c.read(reticulumFlagsProvider.notifier).setBridgeEnabled(true);
        await _pump();
        expect(
          c.read(reticulumBridgeProvider).value!.status.kind,
          ReticulumBridgeStatusKind.connected,
        );

        // Flip bridge off.
        await c.read(reticulumFlagsProvider.notifier).setBridgeEnabled(false);
        await _pump();
        expect(socket.closed, isTrue);
        expect(
          c.read(reticulumBridgeProvider).value!.status.kind,
          ReticulumBridgeStatusKind.disconnected,
        );

        // Frames pushed after disable must NOT be forwarded.
        ctrl.add(_frame(7));
        await _pump();
        expect(socket.writes, isEmpty);
      },
    );
  });

  group('ReticulumBridgeProvider — frame forwarding', () {
    test('forwards reassembled frame body as HDLC-encoded bytes', () async {
      final factory = _FakeFactory();
      final socket = _FakeBridgeSocket();
      factory.queueSocket(socket);
      final ctrl = StreamController<ReticulumFrame>.broadcast();
      addTearDown(ctrl.close);
      final c = _makeContainer(factory: factory, frames: ctrl.stream);

      await c.read(reticulumBridgeProvider.future);
      await c.read(reticulumFlagsProvider.notifier).setReassemblyEnabled(true);
      await c.read(reticulumFlagsProvider.notifier).setBridgeEnabled(true);
      await _pump();

      final frame = _frame(0);
      ctrl.add(frame);
      await _pump();

      expect(socket.writes, hasLength(1));
      expect(socket.writes.single, ReticulumTcpFraming.encodeFrame(frame.body));
      expect(c.read(reticulumBridgeProvider).value!.counters.forwarded, 1);
    });
  });

  group('ReticulumBridgeProvider — error resilience', () {
    test(
      'service connect error does not throw the provider into AsyncError',
      () async {
        final factory = _FakeFactory();
        // Every connect attempt fails — but the service catches and
        // surfaces as status=error.
        for (var i = 0; i < 4; i++) {
          factory.queueError(StateError('boom $i'));
        }
        final ctrl = StreamController<ReticulumFrame>.broadcast();
        addTearDown(ctrl.close);
        final c = _makeContainer(factory: factory, frames: ctrl.stream);

        await c.read(reticulumBridgeProvider.future);
        await c
            .read(reticulumFlagsProvider.notifier)
            .setReassemblyEnabled(true);
        await c.read(reticulumFlagsProvider.notifier).setBridgeEnabled(true);
        await _pump();

        final state = c.read(reticulumBridgeProvider);
        expect(state, isA<AsyncData<ReticulumBridgeUiState>>());
        expect(state.value!.status.kind, ReticulumBridgeStatusKind.error);
        expect(state.value!.counters.connectErrors, greaterThanOrEqualTo(1));
      },
    );
  });

  group('ReticulumBridgeProvider — persistence', () {
    test('setHost persists to SharedPreferences', () async {
      final factory = _FakeFactory();
      final ctrl = StreamController<ReticulumFrame>.broadcast();
      addTearDown(ctrl.close);
      final c = _makeContainer(factory: factory, frames: ctrl.stream);
      await c.read(reticulumBridgeProvider.future);

      await c.read(reticulumBridgeProvider.notifier).setHost('192.168.1.50');
      await _pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reticulum.bridgeHost'), '192.168.1.50');
      expect(c.read(reticulumBridgeProvider).value!.host, '192.168.1.50');
    });

    test('setPort persists to SharedPreferences', () async {
      final factory = _FakeFactory();
      final ctrl = StreamController<ReticulumFrame>.broadcast();
      addTearDown(ctrl.close);
      final c = _makeContainer(factory: factory, frames: ctrl.stream);
      await c.read(reticulumBridgeProvider.future);

      await c.read(reticulumBridgeProvider.notifier).setPort(9999);
      await _pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reticulum.bridgePort'), 9999);
      expect(c.read(reticulumBridgeProvider).value!.port, 9999);
    });
  });

  group('ReticulumBridgeProvider — dispose hygiene', () {
    test(
      'dispose cancels frame subscription so post-dispose frames are no-ops',
      () async {
        final factory = _FakeFactory();
        final socket = _FakeBridgeSocket();
        factory.queueSocket(socket);
        final ctrl = StreamController<ReticulumFrame>.broadcast();
        addTearDown(ctrl.close);

        final c = ProviderContainer(
          overrides: [
            reticulumBridgeSocketFactoryProvider.overrideWithValue(
              factory.connect,
            ),
            reticulumBridgeFrameSourceProvider.overrideWithValue(ctrl.stream),
          ],
        );
        await c.read(reticulumBridgeProvider.future);
        await c
            .read(reticulumFlagsProvider.notifier)
            .setReassemblyEnabled(true);
        await c.read(reticulumFlagsProvider.notifier).setBridgeEnabled(true);
        await _pump();
        expect(
          c.read(reticulumBridgeProvider).value!.status.kind,
          ReticulumBridgeStatusKind.connected,
        );

        c.dispose();
        // Push a frame after dispose. Provider's frame subscription
        // must have been cancelled — no exception, no writes.
        ctrl.add(_frame(1));
        await _pump();
        expect(socket.writes, isEmpty);
        expect(socket.closed, isTrue);
      },
    );
  });
}
