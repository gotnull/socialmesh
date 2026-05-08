// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/protocol/meshtastic_readiness_flag.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _FakeTransport extends DeviceTransport {
  _FakeTransport();

  final _stateController = StreamController<DeviceConnectionState>.broadcast();
  final _dataController = StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.network;

  @override
  bool get isConnected => true;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _dataController.close();
  }
}

class _StubProtocol implements ProtocolService {
  // `sync: true` so `emit(...)` fires the listener synchronously in the
  // current zone. Combined with attaching the listener (via
  // `watchdog.start()`) inside the fakeAsync block, this guarantees that
  // Timer.new in the watchdog's `_arm` runs in the fake-clock zone and
  // `async.elapse(...)` actually fires the deadlines.
  final _readinessController = StreamController<OperationalReadiness>.broadcast(
    sync: true,
  );

  @override
  Stream<OperationalReadiness> get readinessStream =>
      _readinessController.stream;

  void emit(OperationalReadiness state) => _readinessController.add(state);

  @override
  Future<void> dispose() async {
    await _readinessController.close();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _makeContainer({
  required _FakeTransport transport,
  required _StubProtocol protocol,
}) {
  return ProviderContainer(
    overrides: [
      transportProvider.overrideWithValue(transport),
      protocolServiceProvider.overrideWithValue(protocol),
    ],
  );
}

RestoreSessionCoordinator _makeCoordinator(
  ProviderContainer container, {
  bool Function()? isAppBackgrounded,
}) {
  return RestoreSessionCoordinator(
    readTransport: () => container.read(transportProvider),
    readProtocol: () => container.read(protocolServiceProvider),
    isUserDisconnected: () => false,
    isAppBackgrounded: isAppBackgrounded ?? () => false,
  );
}

/// Bundles the per-test setup. The watchdog itself is constructed but
/// NOT started — `watchdog.start()` MUST happen inside the `fakeAsync`
/// block so the readiness-stream listener captures the fake clock zone.
class _Setup {
  _Setup({this.isAppBackgrounded = _alwaysForeground});

  static bool _alwaysForeground() => false;

  final transport = _FakeTransport();
  final protocol = _StubProtocol();
  late final ProviderContainer container;
  late final RestoreSessionCoordinator coordinator;
  late final ReadinessWatchdog watchdog;
  int rebuildCount = 0;
  final bool Function() isAppBackgrounded;

  /// Reference epoch for the test clock. Per-call value is computed as
  /// `_clockEpoch + currentFakeAsyncElapsed`.
  static final DateTime _clockEpoch = DateTime(2026, 1, 1);

  /// Updated by the test from inside `fakeAsync` so the watchdog's
  /// backoff window advances with the fake clock.
  Duration fakeElapsed = Duration.zero;

  void initWith({required MeshtasticReadinessFlags flags}) {
    container = _makeContainer(transport: transport, protocol: protocol);
    coordinator = _makeCoordinator(
      container,
      isAppBackgrounded: isAppBackgrounded,
    );
    watchdog = ReadinessWatchdog(
      flags: flags,
      coordinator: coordinator,
      readinessStream: protocol.readinessStream,
      triggerRebuild: () async {
        rebuildCount++;
      },
      isAppBackgrounded: isAppBackgrounded,
      clock: () => _clockEpoch.add(fakeElapsed),
    );
  }

  Future<void> teardown() async {
    await watchdog.stop();
    container.dispose();
    await transport.dispose();
    await protocol.dispose();
  }
}

void main() {
  group('ReadinessWatchdog', () {
    test('start() is a no-op when flag is disabled', () async {
      final s = _Setup()..initWith(flags: MeshtasticReadinessFlags.disabled);
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        s.protocol.emit(OperationalReadiness.handshakePhase1);
        s.protocol.emit(OperationalReadiness.handshakePhase2);
        async.elapse(const Duration(seconds: 25));
        async.flushMicrotasks();
      });

      expect(s.rebuildCount, 0);
    });

    test('rebuild fires when readiness stays wedged past total deadline', () {
      final s = _Setup()
        ..initWith(
          flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
        );
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        // Past phase-1 deadline — log fires but no rebuild yet.
        async.elapse(const Duration(seconds: 13));
        async.flushMicrotasks();
        expect(s.rebuildCount, 0);
        // Past total deadline — rebuild fires.
        async.elapse(const Duration(seconds: 8));
        async.flushMicrotasks();
        expect(s.rebuildCount, 1);
      });
    });

    test('reaching ready before deadline cancels timers; no rebuild', () {
      final s = _Setup()
        ..initWith(
          flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
        );
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        async.elapse(const Duration(seconds: 5));
        s.protocol.emit(OperationalReadiness.handshakePhase1);
        async.elapse(const Duration(seconds: 5));
        s.protocol.emit(OperationalReadiness.handshakePhase2);
        async.elapse(const Duration(seconds: 5));
        s.protocol.emit(OperationalReadiness.ready);
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
      });

      expect(s.rebuildCount, 0);
    });

    test('suppressed in background: backgrounded -> total timeout fires '
        'log but skips rebuild', () {
      final s = _Setup(
        isAppBackgrounded: () => true,
      )..initWith(flags: const MeshtasticReadinessFlags(watchdogEnabled: true));
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        async.elapse(const Duration(seconds: 25));
        async.flushMicrotasks();
      });

      expect(
        s.rebuildCount,
        0,
        reason: 'background must suppress watchdog rebuild',
      );
    });

    test(
      'rebuild backoff: second wedge within 60 s does not rebuild again',
      () {
        final s = _Setup()
          ..initWith(
            flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
          );
        addTearDown(s.teardown);

        // Advance both fakeAsync's clock AND the watchdog's injected
        // backoff clock together so the 60 s rebuild window observes
        // the same time as the timer firings.
        void elapse(FakeAsync async, Duration d) {
          async.elapse(d);
          s.fakeElapsed += d;
        }

        fakeAsync((async) {
          s.watchdog.start();
          // First wedge -> rebuild fires at 20 s.
          s.protocol.emit(OperationalReadiness.linkConnected);
          elapse(async, const Duration(seconds: 21));
          async.flushMicrotasks();
          expect(s.rebuildCount, 1);

          // Re-wedge within 60 s -> backoff suppresses.
          s.protocol.emit(OperationalReadiness.idle);
          s.protocol.emit(OperationalReadiness.linkConnected);
          elapse(async, const Duration(seconds: 21));
          async.flushMicrotasks();
          expect(s.rebuildCount, 1, reason: '60 s backoff in effect');

          // Past the 60 s window -> rebuild allowed again.
          elapse(async, const Duration(seconds: 45));
          s.protocol.emit(OperationalReadiness.idle);
          s.protocol.emit(OperationalReadiness.linkConnected);
          elapse(async, const Duration(seconds: 21));
          async.flushMicrotasks();
          expect(s.rebuildCount, 2);
        });
      },
    );

    test('re-arm during the same gen cancels prior timers; orphan total cannot '
        'fire after readiness reaches ready', () {
      final s = _Setup()
        ..initWith(
          flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
        );
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        // Arm at linkConnected.
        s.protocol.emit(OperationalReadiness.linkConnected);
        // Past phase-1 (18 s), still inside total deadline (20 s).
        async.elapse(const Duration(seconds: 19));
        // Re-emit handshakePhase2. With the buggy `_arm()` this
        // would create a fresh phase-1+total pair while the original
        // total (deadline at 20 s) was still pending — orphan. With
        // the fix, the previous pair is cancelled before fresh ones
        // are created.
        s.protocol.emit(OperationalReadiness.handshakePhase2);
        // Drive past where the ORIGINAL (now-orphaned) total would
        // have fired.
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        // Promote to ready before the new pair's total deadline.
        s.protocol.emit(OperationalReadiness.ready);
        // Way past where any timer could plausibly fire.
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
      });

      expect(
        s.rebuildCount,
        0,
        reason:
            'no rebuild may fire after readiness reaches ready, even when '
            'a prior arm left a total timer with an unexpired deadline',
      );
    });

    test('re-emitting the same wedge state during the same gen is idempotent '
        '(arm_skipped path keeps the original timers)', () {
      final s = _Setup()
        ..initWith(
          flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
        );
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        // Without elapsing past either deadline, re-emit a couple of
        // intermediate states. The watchdog must NOT replace the
        // original timers and MUST NOT rebuild prematurely.
        s.protocol.emit(OperationalReadiness.handshakePhase1);
        s.protocol.emit(OperationalReadiness.handshakePhase2);
        // Genuine wedge: still not ready past total deadline.
        async.elapse(const Duration(seconds: 21));
        async.flushMicrotasks();
      });

      expect(
        s.rebuildCount,
        1,
        reason:
            'idempotent re-emits keep the original total timer alive; '
            'it fires once at 20 s',
      );
    });

    test('phase-1 deadline is 18 s: a 14-second phase-1 path emits no warning '
        'because readiness moved past handshakePhase1', () {
      final s = _Setup()
        ..initWith(
          flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
        );
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        // 14 s into the arm — firmware-typical phase-1 completion.
        async.elapse(const Duration(seconds: 14));
        s.protocol.emit(OperationalReadiness.handshakePhase2);
        // Drive past the 18 s phase-1 deadline. Phase-1 timer fires
        // but the readiness check inside the callback suppresses the
        // warning because state is no longer linkConnected/phase1.
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
      });

      // No rebuild yet — still inside total deadline (14 + 5 = 19 s,
      // total at 20 s).
      expect(s.rebuildCount, 0);
      // Watchdog still armed (only phase-1 timer fired; total still
      // pending until 20 s).
      expect(s.watchdog.armedGenerationForTesting, 0);
    });

    test('phase-1 timeout still fires when readiness is genuinely stuck at '
        'linkConnected past the 18 s deadline', () {
      final s = _Setup()
        ..initWith(
          flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
        );
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        // Past phase-1 deadline but inside total deadline.
        async.elapse(const Duration(seconds: 19));
        async.flushMicrotasks();
      });

      // Phase-1 is informational only; no rebuild fires from it.
      expect(s.rebuildCount, 0);
      expect(
        s.watchdog.armedGenerationForTesting,
        isNotNull,
        reason:
            'phase-1 timeout does NOT clear the armed generation; '
            'the total timer is still in flight',
      );
      expect(
        s.watchdog.lastReadinessForTesting,
        OperationalReadiness.linkConnected,
      );
    });

    test('reaching ready clears the armed generation; no follow-up callback '
        'can reference it', () {
      final s = _Setup()
        ..initWith(
          flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
        );
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        expect(s.watchdog.armedGenerationForTesting, 0);
        s.protocol.emit(OperationalReadiness.ready);
        expect(
          s.watchdog.armedGenerationForTesting,
          isNull,
          reason: '`ready` must cancel timers and null `_armedGeneration`',
        );
        // Even if some pre-cancellation timer firing slipped through,
        // identity + readiness checks suppress it.
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
      });

      expect(s.rebuildCount, 0);
    });

    test('stale-generation suppress: total timeout for an old gen does not '
        'rebuild when coordinator generation has advanced', () {
      final s = _Setup()
        ..initWith(
          flags: const MeshtasticReadinessFlags(watchdogEnabled: true),
        );
      addTearDown(s.teardown);

      fakeAsync((async) {
        s.watchdog.start();
        s.protocol.emit(OperationalReadiness.linkConnected);
        async.elapse(const Duration(seconds: 10));
        // Simulate a newer restore taking over (manual reconnect tap).
        s.coordinator.invalidate('manual_takeover');
        async.elapse(const Duration(seconds: 11));
        async.flushMicrotasks();
      });

      expect(
        s.rebuildCount,
        0,
        reason:
            'stale-gen check must skip rebuild when a newer restore '
            'has taken over',
      );
    });
  });
}
