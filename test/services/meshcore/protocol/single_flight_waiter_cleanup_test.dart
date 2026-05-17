// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the cleanup invariant for the single-flight waiter map in
// MeshCoreSession: if a send throws after a waiter has been
// registered, the waiter MUST be removed so the next call on the
// same response code does not hit a same-generation single-flight
// violation. Crashlytics [A f1e904cd].

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _ThrowOnSendTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> sendRaw(Uint8List data) async {
    if (!_connected) {
      throw StateError('Transport not connected');
    }
    throw StateError('Simulated transport-layer send error');
  }

  void disconnect() {
    _connected = false;
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

void main() {
  group('sendAndWait waiter cleanup on send failure', () {
    test(
      'orphan waiter removed when sendFrame throws (transport error)',
      () async {
        final transport = _ThrowOnSendTransport();
        final session = MeshCoreSession(transport);

        await expectLater(
          session.sendAndWait(
            MeshCoreCommands.getStats,
            payload: Uint8List.fromList([MeshCoreStatsType.core]),
            expectedResponse: MeshCoreResponses.stats,
            timeout: const Duration(milliseconds: 50),
          ),
          throwsStateError,
        );

        expect(
          session.hasWaiter(MeshCoreResponses.stats),
          isFalse,
          reason:
              'sendFrame threw, but the waiter for 0x18 was not removed. '
              'Next sendAndWait would hit single-flight violation.',
        );

        await session.dispose();
        await transport.dispose();
      },
    );

    test('second sendAndWait on same response code does NOT collide after a '
        'prior send failure', () async {
      final transport = _ThrowOnSendTransport();
      final session = MeshCoreSession(transport);

      await expectLater(
        session.sendAndWait(
          MeshCoreCommands.getStats,
          payload: Uint8List.fromList([MeshCoreStatsType.core]),
          expectedResponse: MeshCoreResponses.stats,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsStateError,
      );

      // The second call must surface the SAME transport StateError
      // (the send still fails), NOT the single-flight StateError
      // from a stale waiter. We pin this by asserting hasWaiter is
      // false before the second call so the register-side check
      // would not throw.
      expect(session.hasWaiter(MeshCoreResponses.stats), isFalse);

      await expectLater(
        session.sendAndWait(
          MeshCoreCommands.getStats,
          payload: Uint8List.fromList([MeshCoreStatsType.core]),
          expectedResponse: MeshCoreResponses.stats,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsStateError,
      );

      expect(session.hasWaiter(MeshCoreResponses.stats), isFalse);

      await session.dispose();
      await transport.dispose();
    });

    test(
      'orphan waiter removed when transport is disconnected mid-flight',
      () async {
        final transport = _ThrowOnSendTransport();
        transport.disconnect();
        final session = MeshCoreSession(transport);

        await expectLater(
          session.sendAndWait(
            MeshCoreCommands.getStats,
            payload: Uint8List.fromList([MeshCoreStatsType.core]),
            expectedResponse: MeshCoreResponses.stats,
            timeout: const Duration(milliseconds: 50),
          ),
          throwsStateError,
        );

        expect(session.hasWaiter(MeshCoreResponses.stats), isFalse);

        await session.dispose();
        await transport.dispose();
      },
    );
  });
}
