// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34a — `meshCoreChatTrafficProvider` regression pins.
//
// Pins:
//   - With no session, the provider returns the empty snapshot.
//   - With a session, the provider exposes the live limiter snapshot.
//   - `recordSend` on the live limiter becomes visible after
//     refreshNow() (the 1 Hz tick is exercised by an explicit refresh
//     so the test stays deterministic).
//   - Swapping the session to null clears the snapshot.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _FakeTransport implements MeshCoreTransport {
  final _rx = StreamController<Uint8List>.broadcast();
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {}

  @override
  bool get isConnected => _connected;

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('meshCoreChatTrafficProvider', () {
    test('returns empty snapshot when no session is connected', () {
      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final snap = container.read(meshCoreChatTrafficProvider);
      expect(snap.currentWindowSentBytes, 0);
      expect(snap.windowCapacityBytes, 1024);
      expect(snap.remainingBytes, 1024);
      expect(snap.peakWindowUsage, 0);
      expect(snap.lastRejection, isNull);
      expect(snap.isIdle, isTrue);
    });

    test('exposes the live limiter snapshot from the session', () async {
      final tx = _FakeTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      // Initial read.
      var snap = container.read(meshCoreChatTrafficProvider);
      expect(snap.currentWindowSentBytes, 0);

      // Record a send on the live limiter.
      lim.recordSend(
        kind: MeshCoreSendKind.plainContact,
        bytes: 64,
        allowed: true,
      );

      // Force a refresh — production uses a 1 Hz Timer, but the test
      // drives the Notifier explicitly to stay deterministic.
      container.read(meshCoreChatTrafficProvider.notifier).refreshNow();
      snap = container.read(meshCoreChatTrafficProvider);
      expect(snap.currentWindowSentBytes, 64);
      expect(snap.sendCountByKind[MeshCoreSendKind.plainContact], 1);
    });

    test('reflects rejections via the lastRejection timestamp', () async {
      final tx = _FakeTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      lim.recordSend(
        kind: MeshCoreSendKind.replyChannel,
        bytes: 50,
        allowed: false,
      );
      container.read(meshCoreChatTrafficProvider.notifier).refreshNow();
      final snap = container.read(meshCoreChatTrafficProvider);
      expect(snap.lastRejection, isNotNull);
      expect(snap.rejectedCountByKind[MeshCoreSendKind.replyChannel], 1);
    });
  });
}
