// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D28 Part D - queue status state transitions on MeshCoreConversationsState.
//
// Pins:
// - heartbeatActive flips when the heartbeat timer is started/stopped
// - activeDrainSource fills in for the duration of an in-flight drain
// - lastDrainSource / lastDrainOutcome / lastDrainAt land after the
//   drain completes (success OR failure path)
// - copyWith respects clearActiveDrainSource

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/providers/app_lifecycle_provider.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _FakeTransport implements MeshCoreTransport {
  final _rxController = StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rxController.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(data);
  }

  @override
  bool get isConnected => _connected;

  void emitFrame(MeshCoreFrame frame) {
    _rxController.add(frame.toBytes());
  }

  Future<void> dispose() async {
    _connected = false;
    await _rxController.close();
  }
}

ProviderContainer _container({required MeshCoreSession? session}) {
  return ProviderContainer(
    overrides: [
      meshCoreSessionProvider.overrideWithValue(session),
      appLifecycleProvider.overrideWith(() => _ForegroundLifecycle()),
      meshCoreContactsProvider.overrideWith(_SettledRoster.new),
    ],
  );
}

/// Roster that has already loaded, so automatic drains are not held back.
class _SettledRoster extends MeshCoreContactsNotifier {
  @override
  MeshCoreContactsState build() =>
      MeshCoreContactsState(lastRefresh: DateTime(2026));
}

class _ForegroundLifecycle extends AppLifecycleNotifier {
  @override
  bool build() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MeshCoreConversationsState - queue status fields', () {
    test('initial state has every queue field empty / off', () {
      const s = MeshCoreConversationsState.initial();
      expect(s.heartbeatActive, isFalse);
      expect(s.activeDrainSource, isNull);
      expect(s.lastDrainSource, isNull);
      expect(s.lastDrainOutcome, isNull);
      expect(s.lastDrainAt, isNull);
    });

    test('copyWith preserves last-drain fields when not specified', () {
      final s = MeshCoreConversationsState(
        lastDrainSource: MeshCoreDrainSource.manual,
        lastDrainOutcome: MeshCoreDrainOutcomeKind.message,
        lastDrainAt: DateTime.utc(2026, 5, 6, 17),
        heartbeatActive: true,
      );
      final after = s.copyWith(isLoading: true);
      expect(after.isLoading, isTrue);
      expect(after.heartbeatActive, isTrue);
      expect(after.lastDrainSource, MeshCoreDrainSource.manual);
      expect(after.lastDrainOutcome, MeshCoreDrainOutcomeKind.message);
      expect(after.lastDrainAt, DateTime.utc(2026, 5, 6, 17));
    });

    test(
      'copyWith activeDrainSource flips and clearActiveDrainSource resets',
      () {
        final s = const MeshCoreConversationsState.initial().copyWith(
          activeDrainSource: MeshCoreDrainSource.heartbeat,
        );
        expect(s.activeDrainSource, MeshCoreDrainSource.heartbeat);

        final cleared = s.copyWith(clearActiveDrainSource: true);
        expect(cleared.activeDrainSource, isNull);
      },
    );

    test(
      'copyWith clearActiveDrainSource takes precedence over a passed source',
      () {
        // Sanity: when both `clearActiveDrainSource:true` and
        // `activeDrainSource: foo` are supplied, the clear flag wins so
        // post-drain state always lands on null.
        final s = const MeshCoreConversationsState.initial().copyWith(
          activeDrainSource: MeshCoreDrainSource.tickle,
        );
        final cleared = s.copyWith(
          clearActiveDrainSource: true,
          activeDrainSource: MeshCoreDrainSource.manual,
        );
        expect(cleared.activeDrainSource, isNull);
      },
    );
  });

  group('MeshCoreConversationsNotifier heartbeat publishes state', () {
    setUp(() {
      MeshCoreConversationsNotifier.debugHeartbeatInterval = const Duration(
        milliseconds: 100,
      );
    });

    tearDown(() {
      MeshCoreConversationsNotifier.debugResetHeartbeatInterval();
    });

    test(
      'heartbeatActive=true after notifier builds with a live session',
      () async {
        final transport = _FakeTransport();
        addTearDown(transport.dispose);
        final session = MeshCoreSession(transport);

        final c = _container(session: session);
        addTearDown(c.dispose);

        // Build the notifier (constructor wires the heartbeat).
        c.read(meshCoreConversationsProvider);
        // `_publishHeartbeatActive` schedules a `Future<void>(...)` to
        // write state on the NEXT event-loop turn (deferred so build's
        // initial-state commit lands first; mirrors
        // `_loadConversations`). A fixed sleep races with that posted
        // Future under load (one of the FlutterTest IDE runs showed
        // the failure mode). Poll-with-timeout drains the event loop
        // until the expected state lands or we hit a generous bound.
        await _pumpUntil(
          () => c.read(meshCoreConversationsProvider).heartbeatActive,
        );

        final state = c.read(meshCoreConversationsProvider);
        expect(state.heartbeatActive, isTrue);
      },
    );

    test('heartbeatActive=false when no session is available', () async {
      final c = _container(session: null);
      addTearDown(c.dispose);

      c.read(meshCoreConversationsProvider);
      await _pumpUntil(
        () => !c.read(meshCoreConversationsProvider).heartbeatActive,
      );
      final state = c.read(meshCoreConversationsProvider);
      expect(state.heartbeatActive, isFalse);
    });

    test('a channel data reply does not stall the drain', () async {
      final transport = _FakeTransport();
      addTearDown(transport.dispose);
      final session = MeshCoreSession(transport);
      final c = _container(session: session);
      addTearDown(c.dispose);

      bool isSync(Uint8List f) =>
          MeshCoreFrame.fromBytes(f).command ==
          MeshCoreCommands.syncNextMessage;
      int syncs() => transport.sent.where(isSync).length;

      // Building the notifier with a live session drains the queue.
      c.read(meshCoreConversationsProvider);
      await _pumpUntil(() => syncs() >= 1);
      expect(syncs(), 1);

      // The radio answers with queued channel data, which the drain must
      // count as a message and follow with the next sync well inside
      // its 3 s reply timeout.
      transport.emitFrame(
        MeshCoreFrame(
          command: MeshCoreResponses.channelDataRecv,
          payload: Uint8List(12),
        ),
      );
      await _pumpUntil(
        () => syncs() >= 2,
        timeout: const Duration(milliseconds: 1500),
      );
      expect(syncs(), 2);

      transport.emitFrame(
        MeshCoreFrame(
          command: MeshCoreResponses.noMoreMessages,
          payload: Uint8List(0),
        ),
      );
    });

    test('a queued drain skips after the container is disposed', () async {
      final transport = _FakeTransport();
      addTearDown(transport.dispose);
      final session = MeshCoreSession(transport);
      final container = _container(session: session);
      final notifier = container.read(meshCoreConversationsProvider.notifier);
      final queuedDrain = Future.microtask(
        () => notifier.drainOnce(MeshCoreDrainSource.heartbeat),
      );
      container.dispose();

      final outcome = await queuedDrain;
      expect(outcome.kind, MeshCoreDrainOutcomeKind.skipped);
      expect(outcome.skipReason, 'disposed');
      expect(transport.sent, isEmpty);
      expect(notifier.debugIsHeartbeatActive, isFalse);
    });
  });
}

/// Poll an event-loop-bound condition by yielding to pending Futures.
/// Returns once [predicate] is true or [timeout] elapses (the caller
/// then re-checks state and fails the `expect` cleanly).
///
/// The timeout is a wall-clock bound and must stay generous: under a
/// full-suite run the worker isolate's event loop can be starved for
/// hundreds of milliseconds before the notifier's deferred publish
/// future runs. On the happy path this returns within a step or two,
/// so the bound costs nothing when the code is healthy.
Future<void> _pumpUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(step);
  }
}
