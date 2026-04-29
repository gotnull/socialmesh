// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Regression coverage for the duplicate-`DATA_SUBSCRIBED` lifecycle bug.
///
/// `logs.txt` line 174 + 182 showed two `Protocol.start() called` lines
/// for the same instance, followed by two `DATA_SUBSCRIBED to transport`
/// lines. Two paths raced — the network reconnect dispatcher (Path A)
/// and the transport-state listener (Path B) — both calling
/// `protocol.start()` on the same singleton. Result: two listeners on
/// `dataStream`, every inbound packet processed twice.
///
/// `ProtocolService.start()` must now serialise concurrent callers via
/// `_startInFlight` + `_startCompleter`, and skip already-started
/// re-entries via `_isStarted`.

class _ManualTransport extends DeviceTransport {
  final StreamController<List<int>> _data =
      StreamController<List<int>>.broadcast();
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  DeviceConnectionState _state = DeviceConnectionState.connected;

  /// Counts how many times `dataStream.listen` was attached. The
  /// idempotency contract is exactly one listener per session.
  int dataStreamListenCount = 0;

  /// Counts how many times `enableNotifications()` is invoked. A single
  /// `start()` execution should call it exactly once; a duplicate would
  /// double it.
  int enableNotificationsCallCount = 0;

  @override
  TransportType get type => TransportType.network;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode =>
      TransportReconnectMode.directEndpoint;

  @override
  DeviceConnectionState get state => _state;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream {
    dataStreamListenCount++;
    return _data.stream;
  }

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {
    _state = DeviceConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> enableNotifications() async {
    enableNotificationsCallCount++;
  }

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    if (!_data.isClosed) await _data.close();
    if (!_stateController.isClosed) await _stateController.close();
  }
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('protocol_start');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

/// Drives `start()` past its first await without waiting for it to fully
/// resolve. The test only cares about side effects observable in the
/// first ~50 ms (listener count, enableNotifications call count). The
/// orphan future is swallowed via `.catchError` so the test runner
/// doesn't see an unhandled async error when `stop()` later errors the
/// `_configCompleter` inside `start()`.
void _fireStartAndForget(ProtocolService protocol) {
  unawaited(
    protocol.start().catchError((_) {
      // Test owns lifecycle; ignore start failures from cleanup.
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('two start() calls in immediate succession produce only one '
      'dataStream listener and one enableNotifications call', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe.db'),
      );
      await dedupeStore.init();
      final transport = _ManualTransport();
      final protocol = ProtocolService(transport, dedupeStore: dedupeStore);

      _fireStartAndForget(protocol);
      _fireStartAndForget(protocol);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        transport.dataStreamListenCount,
        1,
        reason:
            'Exactly one dataStream listener attached. The second '
            'start() must be intercepted by the in-flight guard.',
      );
      expect(
        transport.enableNotificationsCallCount,
        1,
        reason:
            'enableNotifications() must be called once — second '
            'start() did not re-enter the body.',
      );

      protocol.stop();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await transport.dispose();
      await dedupeStore.dispose();
    });
  }, timeout: const Timeout(Duration(seconds: 5)));

  test(
    'five concurrent start() calls only attach one listener',
    () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();
        final transport = _ManualTransport();
        final protocol = ProtocolService(transport, dedupeStore: dedupeStore);

        for (var i = 0; i < 5; i++) {
          _fireStartAndForget(protocol);
        }

        // Wait long enough for the in-flight start() to reach its
        // `_configCompleter.future.timeout(...)` await (past the 200 ms
        // post-enableNotifications delay AND the 100 ms heartbeat
        // post-send delay). Without this, `stop()` fires
        // `completeError` on a future with no listener, raising an
        // unhandled async error that the test framework reports.
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(transport.dataStreamListenCount, 1);
        expect(transport.enableNotificationsCallCount, 1);

        protocol.stop();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await transport.dispose();
        await dedupeStore.dispose();
      });
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'stop() resets `_isStarted` so a fresh start() runs the body again',
    () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();
        final transport = _ManualTransport();
        final protocol = ProtocolService(transport, dedupeStore: dedupeStore);

        _fireStartAndForget(protocol);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(transport.enableNotificationsCallCount, 1);
        expect(transport.dataStreamListenCount, 1);

        protocol.stop();
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // After stop, the lifecycle flags are cleared. A fresh start()
        // must run the body again rather than skipping with
        // PROTOCOL_START_SKIPPED_ALREADY_STARTED.
        _fireStartAndForget(protocol);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(
          transport.enableNotificationsCallCount,
          2,
          reason:
              'After stop() and a fresh start(), the body must execute '
              'again — no SKIPPED_ALREADY_STARTED short-circuit.',
        );
        expect(transport.dataStreamListenCount, 2);

        protocol.stop();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await transport.dispose();
        await dedupeStore.dispose();
      });
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
