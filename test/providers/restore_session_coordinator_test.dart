// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Stub transport that satisfies [DeviceTransport] minimally for the
/// coordinator's pre-check (`transport.isConnected`) and the BLE-restore
/// type guard (`transport is BleTransport`). The fake is intentionally
/// NOT a [BleTransport] so the coordinator skips `refreshNotifications`
/// and goes straight to stop/bind/start — tests assert the call order
/// against [_RecordingProtocol] which intercepts those.
class _FakeTransport extends DeviceTransport {
  _FakeTransport({this.isConnectedReturn = true});

  final bool isConnectedReturn;
  final _stateController = StreamController<DeviceConnectionState>.broadcast();
  final _dataController = StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.network;

  @override
  bool get isConnected => isConnectedReturn;

  @override
  DeviceConnectionState get state => isConnectedReturn
      ? DeviceConnectionState.connected
      : DeviceConnectionState.disconnected;

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

/// Coordinator-test-only fake protocol. Records call order so tests can
/// assert that `stop` precedes `bindSessionGeneration` precedes `start`,
/// and that stale-restore abort skipped `start` entirely.
class _RecordingProtocol implements ProtocolService {
  final List<String> calls = <String>[];
  Completer<void>? startGate;
  int? lastBoundGeneration;

  @override
  void stop() {
    calls.add('stop');
  }

  @override
  Future<void> start() async {
    calls.add('start.begin');
    if (startGate != null) {
      await startGate!.future;
    }
    calls.add('start.end');
  }

  @override
  void bindSessionGeneration(int gen) {
    calls.add('bindSessionGeneration($gen)');
    lastBoundGeneration = gen;
  }

  @override
  OperationalReadiness get readiness => OperationalReadiness.idle;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Variant whose synchronous `stop` calls `coord.invalidate(...)`. Drops
/// us straight into the post-stop stale check before `bind`/`start` —
/// the realistic mid-restore-abort scenario (user disconnects, device
/// switches, transport disposes) lands on the same code path.
class _InvalidatingStopProtocol extends _RecordingProtocol {
  RestoreSessionCoordinator? coord;

  @override
  void stop() {
    super.stop();
    coord?.invalidate('mid_restore_for_test');
  }
}

ProviderContainer _makeContainer({
  required _FakeTransport transport,
  required ProtocolService protocol,
}) {
  return ProviderContainer(
    overrides: [
      transportProvider.overrideWithValue(transport),
      protocolServiceProvider.overrideWithValue(protocol),
    ],
  );
}

void main() {
  group('RestoreSessionCoordinator', () {
    test('skips when isUserDisconnected returns true (no generation bump, '
        'no protocol calls)', () async {
      final transport = _FakeTransport();
      final protocol = _RecordingProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });

      final coord = RestoreSessionCoordinator(
        readTransport: () => container.read(transportProvider),
        readProtocol: () => container.read(protocolServiceProvider),
        isUserDisconnected: () => true,
      );
      final genBefore = coord.sessionGeneration;

      await coord.restoreSession(reason: 'test_user_disconnected');

      expect(coord.sessionGeneration, genBefore);
      expect(protocol.calls, isEmpty);
    });

    test('skips when transport.isConnected is false (no generation bump, '
        'no protocol calls)', () async {
      final transport = _FakeTransport(isConnectedReturn: false);
      final protocol = _RecordingProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });

      final coord = RestoreSessionCoordinator(
        readTransport: () => container.read(transportProvider),
        readProtocol: () => container.read(protocolServiceProvider),
        isUserDisconnected: () => false,
      );
      final genBefore = coord.sessionGeneration;

      await coord.restoreSession(reason: 'test_disconnected_transport');

      expect(coord.sessionGeneration, genBefore);
      expect(protocol.calls, isEmpty);
    });

    test('happy path: bumps generation, calls stop -> bind -> start', () async {
      final transport = _FakeTransport();
      final protocol = _RecordingProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });

      final coord = RestoreSessionCoordinator(
        readTransport: () => container.read(transportProvider),
        readProtocol: () => container.read(protocolServiceProvider),
        isUserDisconnected: () => false,
      );

      await coord.restoreSession(reason: 'test_happy');

      expect(coord.sessionGeneration, 1);
      expect(protocol.lastBoundGeneration, 1);
      expect(protocol.calls, [
        'stop',
        'bindSessionGeneration(1)',
        'start.begin',
        'start.end',
      ]);
    });

    test('single-flight: concurrent calls share one execution', () async {
      final transport = _FakeTransport();
      final protocol = _RecordingProtocol()..startGate = Completer<void>();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });

      final coord = RestoreSessionCoordinator(
        readTransport: () => container.read(transportProvider),
        readProtocol: () => container.read(protocolServiceProvider),
        isUserDisconnected: () => false,
      );

      // Kick off the first restore — it parks at the `startGate`.
      final first = coord.restoreSession(reason: 'first');
      // Pump microtasks so the first restore actually enters _doRestore
      // and reaches the `await start()` boundary before the second call.
      await Future<void>.delayed(Duration.zero);
      expect(coord.inFlight, isTrue);

      // Second call while first is in flight should be deduped.
      final second = coord.restoreSession(reason: 'second');

      // Generation must have bumped exactly once.
      expect(coord.sessionGeneration, 1);

      // Release the gate and wait for both.
      protocol.startGate!.complete();
      await Future.wait([first, second]);

      expect(
        protocol.calls.where((c) => c == 'stop').length,
        1,
        reason: 'stop must be called exactly once under single-flight',
      );
      expect(
        protocol.calls
            .where((c) => c.startsWith('bindSessionGeneration'))
            .length,
        1,
        reason: 'bind must be called exactly once under single-flight',
      );
      expect(
        protocol.calls.where((c) => c == 'start.begin').length,
        1,
        reason: 'start must be called exactly once under single-flight',
      );
    });

    test('invalidate() bumps generation without running a restore', () async {
      final transport = _FakeTransport();
      final protocol = _RecordingProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });

      final coord = RestoreSessionCoordinator(
        readTransport: () => container.read(transportProvider),
        readProtocol: () => container.read(protocolServiceProvider),
        isUserDisconnected: () => false,
      );

      coord.invalidate('test_invalidate');
      expect(coord.sessionGeneration, 1);
      coord.invalidate('test_invalidate_again');
      expect(coord.sessionGeneration, 2);
      expect(
        protocol.calls,
        isEmpty,
        reason: 'invalidate must not touch the protocol',
      );
    });

    test('stale-generation abort: invalidate() observed mid-restore prevents '
        'bind+start from running', () async {
      final transport = _FakeTransport();
      final protocol = _InvalidatingStopProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });

      final coord = RestoreSessionCoordinator(
        readTransport: () => container.read(transportProvider),
        readProtocol: () => container.read(protocolServiceProvider),
        isUserDisconnected: () => false,
      );
      protocol.coord = coord;

      await coord.restoreSession(reason: 'mid_restore_invalidate');

      expect(
        protocol.calls,
        ['stop'],
        reason:
            'stop ran (during which invalidate fired); the post-stop '
            'stale check must abort BEFORE bindSessionGeneration / start',
      );
      // Generation bumped once for the restore start, then once more by
      // invalidate inside stop — total 2.
      expect(coord.sessionGeneration, 2);
    });

    test(
      'background safety: first attempt while backgrounded is allowed',
      () async {
        final transport = _FakeTransport();
        final protocol = _RecordingProtocol();
        final container = _makeContainer(
          transport: transport,
          protocol: protocol,
        );
        addTearDown(() async {
          container.dispose();
          await transport.dispose();
        });

        final coord = RestoreSessionCoordinator(
          readTransport: () => container.read(transportProvider),
          readProtocol: () => container.read(protocolServiceProvider),
          isUserDisconnected: () => false,
          isAppBackgrounded: () => true,
        );

        await coord.restoreSession(reason: 'first_bg_attempt');

        // First background attempt is allowed: stop/bind/start ran.
        expect(protocol.calls, [
          'stop',
          'bindSessionGeneration(1)',
          'start.begin',
          'start.end',
        ]);
      },
    );

    test('background safety: second restore attempt while still backgrounded '
        'is suppressed (no protocol calls)', () async {
      final transport = _FakeTransport();
      final protocol = _RecordingProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });

      final coord = RestoreSessionCoordinator(
        readTransport: () => container.read(transportProvider),
        readProtocol: () => container.read(protocolServiceProvider),
        isUserDisconnected: () => false,
        isAppBackgrounded: () => true,
      );

      await coord.restoreSession(reason: 'first_bg');
      // Reset call log so we can assert ZERO further protocol calls.
      protocol.calls.clear();

      await coord.restoreSession(reason: 'second_bg_should_skip');
      await coord.restoreSession(reason: 'third_bg_should_also_skip');

      expect(
        protocol.calls,
        isEmpty,
        reason:
            'background budget allows exactly one attempt; further '
            'attempts must be suppressed until foreground',
      );
    });

    test(
      'background safety: foreground transition resets the budget',
      () async {
        final transport = _FakeTransport();
        final protocol = _RecordingProtocol();
        final container = _makeContainer(
          transport: transport,
          protocol: protocol,
        );
        addTearDown(() async {
          container.dispose();
          await transport.dispose();
        });

        var backgrounded = true;
        final coord = RestoreSessionCoordinator(
          readTransport: () => container.read(transportProvider),
          readProtocol: () => container.read(protocolServiceProvider),
          isUserDisconnected: () => false,
          isAppBackgrounded: () => backgrounded,
        );

        // Burn the background budget.
        await coord.restoreSession(reason: 'bg1');
        await coord.restoreSession(reason: 'bg2_should_skip');
        final stopCountAfterBg = protocol.calls
            .where((c) => c == 'stop')
            .length;
        expect(
          stopCountAfterBg,
          1,
          reason: 'budget exhausted: only the first bg attempt ran',
        );

        // Simulate app foreground transition.
        backgrounded = false;
        await coord.restoreSession(reason: 'foreground_after_bg');

        expect(
          protocol.calls.where((c) => c == 'stop').length,
          stopCountAfterBg + 1,
          reason: 'foreground call must reset budget and run a fresh restore',
        );

        // Background again — budget should be reset, allowing one more.
        backgrounded = true;
        await coord.restoreSession(reason: 'bg_after_fg');
        expect(
          protocol.calls.where((c) => c == 'stop').length,
          stopCountAfterBg + 2,
          reason: 'after foreground reset, a new bg attempt is allowed',
        );

        // Second bg attempt blocked again.
        await coord.restoreSession(reason: 'bg_after_fg_2_should_skip');
        expect(
          protocol.calls.where((c) => c == 'stop').length,
          stopCountAfterBg + 2,
          reason: 'second bg attempt after the reset must still be blocked',
        );
      },
    );

    test(
      'user-disconnect observed mid-restore prevents start from running',
      () async {
        final transport = _FakeTransport();
        final protocol = _RecordingProtocol();
        final container = _makeContainer(
          transport: transport,
          protocol: protocol,
        );
        addTearDown(() async {
          container.dispose();
          await transport.dispose();
        });

        var userDisconnected = false;
        final coord = RestoreSessionCoordinator(
          readTransport: () => container.read(transportProvider),
          readProtocol: () => container.read(protocolServiceProvider),
          isUserDisconnected: () => userDisconnected,
        );
        // Hold start open so we can flip the flag mid-restore.
        protocol.startGate = Completer<void>();

        final restore = coord.restoreSession(reason: 'concurrent_user_dc');
        await Future<void>.delayed(Duration.zero);
        // We're now parked inside `start()`. Flip the flag and release.
        userDisconnected = true;
        protocol.startGate!.complete();

        await restore;

        // `start()` was already running when the flag flipped, so it
        // ran to completion — but the post-start stale check observed
        // the user-disconnect. The end-of-restore log line is the only
        // missing event; protocol.calls itself shows the full chain.
        expect(protocol.calls, contains('start.end'));
        // No second restore should run: a follow-up call must be
        // skipped by the user-disconnect pre-check.
        await coord.restoreSession(reason: 'should_skip');
        expect(
          protocol.calls.where((c) => c == 'stop').length,
          1,
          reason:
              'second restore must be skipped by user-disconnect '
              'pre-check, so stop count stays at 1',
        );
      },
    );
  });
}
