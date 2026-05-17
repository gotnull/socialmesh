// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the cleanup invariant for the single-flight waiter map in
// MeshCoreSession: if a send throws after a waiter has been
// registered, the waiter MUST be removed so the next call on the
// same response code does not hit a same-generation single-flight
// violation. Crashlytics [A f1e904cd].
//
// Also pins the StateError-as-null contract: when the transport
// layer throws StateError ("not connected" / "session not active")
// mid-send, `sendAndWait` returns null rather than rethrowing —
// matches the existing TimeoutException semantics so periodic
// pollers don't leak unhandled async errors into Crashlytics.

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

/// Throws a non-StateError so we can prove the catch-all-and-rethrow
/// arm is still in play for surprising failures.
class _ThrowOnSendArgumentError implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  bool get isConnected => true;

  @override
  Future<void> sendRaw(Uint8List data) async {
    throw ArgumentError('Simulated genuinely-surprising failure');
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

void main() {
  group('sendAndWait waiter cleanup on send failure', () {
    test('StateError from sendFrame returns null (matches TimeoutException) '
        'and removes the orphan waiter', () async {
      final transport = _ThrowOnSendTransport();
      final session = MeshCoreSession(transport);

      final result = await session.sendAndWait(
        MeshCoreCommands.getStats,
        payload: Uint8List.fromList([MeshCoreStatsType.core]),
        expectedResponse: MeshCoreResponses.stats,
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isNull);
      expect(
        session.hasWaiter(MeshCoreResponses.stats),
        isFalse,
        reason:
            'sendFrame threw StateError, but the waiter for 0x18 was '
            'not removed. Next sendAndWait would hit single-flight '
            'violation.',
      );

      await session.dispose();
      await transport.dispose();
    });

    test('second sendAndWait on same response code does NOT collide after '
        'a prior StateError send failure', () async {
      final transport = _ThrowOnSendTransport();
      final session = MeshCoreSession(transport);

      final first = await session.sendAndWait(
        MeshCoreCommands.getStats,
        payload: Uint8List.fromList([MeshCoreStatsType.core]),
        expectedResponse: MeshCoreResponses.stats,
        timeout: const Duration(milliseconds: 50),
      );
      expect(first, isNull);
      expect(session.hasWaiter(MeshCoreResponses.stats), isFalse);

      // The second call must also return null (transport still
      // bad), NOT throw single-flight violation from a stale waiter.
      final second = await session.sendAndWait(
        MeshCoreCommands.getStats,
        payload: Uint8List.fromList([MeshCoreStatsType.core]),
        expectedResponse: MeshCoreResponses.stats,
        timeout: const Duration(milliseconds: 50),
      );
      expect(second, isNull);
      expect(session.hasWaiter(MeshCoreResponses.stats), isFalse);

      await session.dispose();
      await transport.dispose();
    });

    test('StateError-as-null also covers the pre-disconnected case '
        '(transport flipped before the first call)', () async {
      final transport = _ThrowOnSendTransport();
      transport.disconnect();
      final session = MeshCoreSession(transport);

      final result = await session.sendAndWait(
        MeshCoreCommands.getStats,
        payload: Uint8List.fromList([MeshCoreStatsType.core]),
        expectedResponse: MeshCoreResponses.stats,
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isNull);
      expect(session.hasWaiter(MeshCoreResponses.stats), isFalse);

      await session.dispose();
      await transport.dispose();
    });

    test('non-StateError send failures still rethrow so genuinely-surprising '
        'errors stay visible', () async {
      final transport = _ThrowOnSendArgumentError();
      final session = MeshCoreSession(transport);

      await expectLater(
        session.sendAndWait(
          MeshCoreCommands.getStats,
          payload: Uint8List.fromList([MeshCoreStatsType.core]),
          expectedResponse: MeshCoreResponses.stats,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsArgumentError,
      );

      // Cleanup still fires even on the rethrow path.
      expect(session.hasWaiter(MeshCoreResponses.stats), isFalse);

      await session.dispose();
      await transport.dispose();
    });
  });
}
