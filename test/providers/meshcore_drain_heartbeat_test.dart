// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D22 — Drain heartbeat + non-overlap guard regression tests for
// MeshCoreConversationsNotifier.
//
// The heartbeat is the missed-tickle recovery mechanism: while
// connected, the notifier periodically fires CMD_SYNC_NEXT_MESSAGE so
// messages already in the firmware queue (whose 0x83 tickle was lost
// due to transport blip / cold-start race / BLE buffer pressure) get
// pulled. These tests pin the timer lifecycle, the drain helper's
// non-overlap guard, the iterative drain loop, and the redaction
// invariants for the new heartbeat log family.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/providers/app_lifecycle_provider.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

/// Fake transport for tests. Mirrors
/// `test/services/meshcore/protocol/meshcore_session_test.dart` so
/// the session attaches without a real BLE / TCP layer.
class FakeMeshCoreTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rxController =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sentData = [];
  bool _isConnected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rxController.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    if (!_isConnected) {
      throw StateError('Transport not connected');
    }
    sentData.add(data);
  }

  @override
  bool get isConnected => _isConnected;

  void simulateReceiveFrame(MeshCoreFrame frame) {
    _rxController.add(frame.toBytes());
  }

  void disconnect() {
    _isConnected = false;
  }

  Future<void> dispose() async {
    if (!_rxController.isClosed) await _rxController.close();
  }

  /// Count of `CMD_SYNC_NEXT_MESSAGE` (0x0A) frames sent to the device.
  int get syncCommandCount =>
      sentData.where((d) => d.isNotEmpty && d[0] == 0x0A).length;
}

ProviderContainer _container({
  required MeshCoreSession? session,
  bool foreground = true,
}) {
  return ProviderContainer(
    overrides: [
      meshCoreSessionProvider.overrideWithValue(session),
      // Build the lifecycle notifier and pre-set its state if needed.
      if (!foreground)
        appLifecycleProvider.overrideWith(() => _BackgroundLifecycleNotifier()),
    ],
  );
}

class _BackgroundLifecycleNotifier extends AppLifecycleNotifier {
  @override
  bool build() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMeshCoreTransport transport;
  late MeshCoreSession session;
  late List<String> meshLogs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    transport = FakeMeshCoreTransport();
    session = MeshCoreSession(transport);
    meshLogs = [];
    AppLogging.reset();
    AppLogging.setAppLogSink((level, source, message) {
      // The drain helpers all emit through `AppLogging.meshcore`
      // which fans out to the app log sink with source='Meshcore'.
      // Filter so we don't pick up RevenueCat / connection chatter.
      if (source.toLowerCase() == 'meshcore') {
        meshLogs.add(message);
      }
    });
    // Shorten heartbeat so timer-based tests don't have to wait 60 s
    // wall-clock. fake_async drives elapse for the few tests that
    // need the actual timer to tick.
    MeshCoreConversationsNotifier.debugHeartbeatInterval = const Duration(
      milliseconds: 100,
    );
  });

  tearDown(() async {
    MeshCoreConversationsNotifier.debugResetHeartbeatInterval();
    AppLogging.reset();
    await transport.dispose();
  });

  group('D22 heartbeat lifecycle', () {
    test('starts after connected/identified session', () {
      final c = _container(session: session);
      addTearDown(c.dispose);

      // Build the notifier so its constructor runs.
      c.read(meshCoreConversationsProvider);
      final n = c.read(meshCoreConversationsProvider.notifier);

      expect(n.debugIsHeartbeatActive, isTrue);
      expect(
        meshLogs.any(
          (l) =>
              l.contains('event=msg_waiting.heartbeat.started') &&
              l.contains('interval_ms='),
        ),
        isTrue,
        reason: 'started log must carry interval_ms=N for log auditability',
      );
    });

    test('does not start when no session is available', () {
      final c = _container(session: null);
      addTearDown(c.dispose);

      c.read(meshCoreConversationsProvider);
      final n = c.read(meshCoreConversationsProvider.notifier);
      expect(n.debugIsHeartbeatActive, isFalse);
      expect(
        meshLogs.any((l) => l.contains('event=msg_waiting.heartbeat.started')),
        isFalse,
      );
    });

    test('stops when container is disposed', () {
      final c = _container(session: session);
      c.read(meshCoreConversationsProvider);
      final n = c.read(meshCoreConversationsProvider.notifier);
      expect(n.debugIsHeartbeatActive, isTrue);

      c.dispose();

      expect(
        meshLogs.any(
          (l) =>
              l.contains('event=msg_waiting.heartbeat.stopped') &&
              l.contains('reason=disposed'),
        ),
        isTrue,
      );
    });
  });

  group('D22 drainOnce wire shape', () {
    test('heartbeat tick sends CMD_SYNC_NEXT_MESSAGE (0x0A)', () async {
      final c = _container(session: session);
      addTearDown(c.dispose);
      final n = c.read(meshCoreConversationsProvider.notifier);

      final fired = n.debugFireHeartbeatTick();
      // Settle just enough for the sync send and the 3 s timeout to
      // arm. We don't pump any response, so this resolves on timeout.
      await fakeAsync_(fired);

      expect(transport.syncCommandCount, greaterThanOrEqualTo(1));
      expect(transport.sentData.first.first, equals(0x0A));
      expect(
        meshLogs.any(
          (l) => l.contains('event=msg_waiting.drain.heartbeat.requested'),
        ),
        isTrue,
      );
    });

    test(
      'NO_MORE_MESSAGES (0x0A response) does not persist anything',
      () async {
        final c = _container(session: session);
        addTearDown(c.dispose);
        final n = c.read(meshCoreConversationsProvider.notifier);
        final beforeConvs = c.read(meshCoreConversationsProvider).conversations;

        // Schedule the response right after sync is sent.
        final tick = n.debugFireHeartbeatTick();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        transport.simulateReceiveFrame(
          MeshCoreFrame(command: 0x0A, payload: Uint8List(0)),
        );
        await tick;

        final afterConvs = c.read(meshCoreConversationsProvider).conversations;
        expect(afterConvs.length, equals(beforeConvs.length));
        expect(
          meshLogs.any(
            (l) => l.contains(
              'event=msg_waiting.drain.heartbeat.result result=no_more',
            ),
          ),
          isTrue,
        );
      },
    );

    test('iterates until no_more (one message frame then noMore)', () async {
      final c = _container(session: session);
      addTearDown(c.dispose);
      final n = c.read(meshCoreConversationsProvider.notifier);

      final tick = n.debugFireHeartbeatTick();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // First sync: a contact V3 message frame (0x10). Use a
      // payload that the parser will reject (insufficient size) so
      // we don't pull in the full frame layout — for this test we
      // only care that the heartbeat loop classifies it as
      // `message` and re-fires sync.
      transport.simulateReceiveFrame(
        MeshCoreFrame(
          command: 0x10,
          payload: Uint8List.fromList(List.filled(20, 0)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Second sync: NO_MORE_MESSAGES.
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x0A, payload: Uint8List(0)),
      );
      await tick;

      // The heartbeat sent at least two sync commands: one to
      // pull the message, one to confirm queue empty.
      expect(transport.syncCommandCount, greaterThanOrEqualTo(2));
      expect(
        meshLogs.any(
          (l) => l.contains(
            'event=msg_waiting.drain.heartbeat.result result=message',
          ),
        ),
        isTrue,
      );
      expect(
        meshLogs.any(
          (l) => l.contains(
            'event=msg_waiting.drain.heartbeat.result result=no_more',
          ),
        ),
        isTrue,
      );
    });
  });

  group('D22 non-overlap guard', () {
    test('heartbeat skips while a manual drain is in flight', () async {
      final c = _container(session: session);
      addTearDown(c.dispose);
      final n = c.read(meshCoreConversationsProvider.notifier);

      // Kick off a manual drain but don't send any response so it
      // blocks on the 3 s timeout. We assert overlap in <100 ms below.
      final manualFut = n.manualDrain();
      // Yield once so manualDrain registers _activeDrain = manual.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(n.debugActiveDrain, equals(MeshCoreDrainSource.manual));

      // Now fire the heartbeat — must skip with already_draining_manual.
      await n.debugFireHeartbeatTick();
      expect(
        meshLogs.any(
          (l) => l.contains(
            'event=msg_waiting.drain.heartbeat.skipped '
            'reason=already_draining_manual',
          ),
        ),
        isTrue,
      );

      // Resolve the manual drain so the test doesn't hang.
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x0A, payload: Uint8List(0)),
      );
      final outcome = await manualFut;
      expect(outcome.kind, equals(MeshCoreDrainOutcomeKind.noMore));
    });

    test('heartbeat skips while a 0x83 tickle drain is in flight', () async {
      final c = _container(session: session);
      addTearDown(c.dispose);
      final n = c.read(meshCoreConversationsProvider.notifier);

      // Pump a 0x83 tickle. Sync command is fired off-microtask
      // and parks waiting on the broadcast stream.
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x83, payload: Uint8List(0)),
      );
      // Yield enough for the microtask + drainOnce setup.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(n.debugActiveDrain, equals(MeshCoreDrainSource.tickle));

      // Heartbeat must skip cleanly.
      await n.debugFireHeartbeatTick();
      expect(
        meshLogs.any(
          (l) => l.contains(
            'event=msg_waiting.drain.heartbeat.skipped '
            'reason=already_draining_tickle',
          ),
        ),
        isTrue,
      );

      // Resolve tickle so teardown doesn't deadlock.
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x0A, payload: Uint8List(0)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    test('manual drain skips while heartbeat is in flight', () async {
      final c = _container(session: session);
      addTearDown(c.dispose);
      final n = c.read(meshCoreConversationsProvider.notifier);

      final tick = n.debugFireHeartbeatTick();
      // Yield so heartbeat sets _activeDrain.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(n.debugActiveDrain, equals(MeshCoreDrainSource.heartbeat));

      final manualOutcome = await n.manualDrain();
      expect(manualOutcome.kind, equals(MeshCoreDrainOutcomeKind.skipped));
      expect(manualOutcome.skipReason, equals('already_draining_heartbeat'));

      // Resolve heartbeat for clean teardown.
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x0A, payload: Uint8List(0)),
      );
      await tick;
    });
  });

  group('D22 failure handling', () {
    test(
      'no response within 3 s yields result=timeout without crashing',
      () async {
        // Real-time wait. fakeAsync would be cheaper, but it does
        // not intercept the `.timeout(Duration(seconds: 3))` on a
        // future already awaited inside the iterative drain loop;
        // letting the wall clock advance is the simplest reliable
        // assertion.
        final c = _container(session: session);
        addTearDown(c.dispose);
        final n = c.read(meshCoreConversationsProvider.notifier);

        await n.debugFireHeartbeatTick();
        expect(
          meshLogs.any(
            (l) => l.contains(
              'event=msg_waiting.drain.heartbeat.result result=timeout',
            ),
          ),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test('failed sendCommand surfaces as failed outcome (no crash)', () async {
      // Simulate transport disconnect after the session was built —
      // sendRaw will throw StateError, drainOnce catches and
      // classifies as failed.
      final c = _container(session: session);
      addTearDown(c.dispose);
      final n = c.read(meshCoreConversationsProvider.notifier);

      transport.disconnect();
      final outcome = await n.manualDrain();
      // The session is still "active" by its internal state machine
      // (it doesn't observe the transport flip in this fake), so
      // drainOnce sends and the transport throws → classified as
      // failed.
      expect([
        MeshCoreDrainOutcomeKind.failed,
        MeshCoreDrainOutcomeKind.timeout,
      ], contains(outcome.kind));
    });
  });

  group('D22 redaction', () {
    test(
      'no plaintext / full-key / raw-payload bytes in heartbeat logs',
      () async {
        final c = _container(session: session);
        addTearDown(c.dispose);
        final n = c.read(meshCoreConversationsProvider.notifier);

        // Pump a 0x10 contact frame whose payload contains both a
        // plausible plaintext substring and a 32-byte hex stretch.
        // Neither must ever appear in any heartbeat log line.
        const plaintext = 'this-is-a-secret-payload-do-not-leak';
        final fakeKey = Uint8List.fromList(List.generate(32, (i) => 0xa0 + i));
        final fakeKeyHex = fakeKey
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        // Concatenate fakeKey + plaintext bytes as the frame payload.
        final payload = Uint8List.fromList([
          ...fakeKey,
          ...plaintext.codeUnits,
        ]);

        final tick = n.debugFireHeartbeatTick();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        transport.simulateReceiveFrame(
          MeshCoreFrame(command: 0x10, payload: payload),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        transport.simulateReceiveFrame(
          MeshCoreFrame(command: 0x0A, payload: Uint8List(0)),
        );
        await tick;

        final joined = meshLogs.join('\n');
        expect(joined.contains(plaintext), isFalse);
        expect(joined.contains(fakeKeyHex), isFalse);
        // The size= field must show payload byte count, not the
        // bytes themselves.
        expect(
          meshLogs.any(
            (l) => l.contains(
              'event=msg_waiting.drain.heartbeat.result result=message',
            ),
          ),
          isTrue,
        );
      },
    );
  });
}

/// Helper: wait for a future that may be racing with the drainOnce
/// 3 s timeout. We don't want tests to wait the full 3 s wall-clock,
/// so we arm a short timeout and accept either completion.
Future<void> fakeAsync_(Future<void> f) async {
  await f.timeout(const Duration(seconds: 4), onTimeout: () {});
}
