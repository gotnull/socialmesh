// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D31 Part B: tests for MeshCoreChannelsNotifier add/edit/remove.
//
// The provider methods are thin wrappers over the session helpers
// pinned by `test/services/meshcore/protocol/d31_channel_crud_test.dart`.
// What this file pins:
//
//   1. Invalid input (bad slot, bad name length, bad PSK length) is
//      rejected BEFORE any wire op (transport.sent stays empty).
//   2. Valid input fires exactly one CMD_SET_CHANNEL frame on the
//      wire.
//   3. add/edit/setChannel converge on the same wire op (firmware's
//      `CMD_SET_CHANNEL` is overwrite-by-slot).
//   4. removeChannel emits the same byte vector as setChannel(idx,
//      "", zeros) — no dedicated delete opcode at the pinned SHA.
//   5. Firmware-error (no OK ack) returns false and does NOT mutate
//      local state.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/models/meshcore_channel.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _RecordingTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => connected;

  void simulateOk() {
    final ok = MeshCoreFrame(
      command: MeshCoreResponses.ok,
      payload: Uint8List(0),
    );
    _rx.add(ok.toBytes());
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

ProviderContainer _buildContainer({required MeshCoreSession session}) {
  return ProviderContainer(
    overrides: [
      // Force the notifier's build() into the disconnected branch so
      // it doesn't auto-fire `_loadChannels` on construction. Tests
      // drive the wire ops manually.
      linkStatusProvider.overrideWithValue(
        const LinkStatus(
          protocol: LinkProtocol.meshcore,
          status: LinkConnectionStatus.disconnected,
        ),
      ),
      meshCoreSessionProvider.overrideWithValue(session),
    ],
  );
}

void main() {
  group('MeshCoreChannelsNotifier.addChannel (D31 Part B)', () {
    test('rejects PSK that is not 16 bytes BEFORE any wire op', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      final container = _buildContainer(session: session);
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreChannelsProvider.notifier);
      final ok = await notifier.addChannel(
        index: 1,
        name: 'Test',
        psk: Uint8List(15), // wrong length
      );

      expect(ok, isFalse);
      expect(
        transport.sent,
        isEmpty,
        reason: 'Invalid PSK length must be rejected before the wire op',
      );

      await session.dispose();
      await transport.dispose();
    });

    test('rejects name longer than 32 bytes BEFORE any wire op', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      final container = _buildContainer(session: session);
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreChannelsProvider.notifier);
      final ok = await notifier.addChannel(
        index: 1,
        name: 'a' * 33,
        psk: Uint8List(16),
      );

      expect(ok, isFalse);
      expect(transport.sent, isEmpty);

      await session.dispose();
      await transport.dispose();
    });

    test('rejects slot index outside u8 range BEFORE any wire op', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      final container = _buildContainer(session: session);
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreChannelsProvider.notifier);
      expect(
        await notifier.addChannel(index: -1, name: 'x', psk: Uint8List(16)),
        isFalse,
      );
      expect(
        await notifier.addChannel(index: 256, name: 'x', psk: Uint8List(16)),
        isFalse,
      );
      expect(transport.sent, isEmpty);

      await session.dispose();
      await transport.dispose();
    });

    test(
      'valid input fires CMD_SET_CHANNEL frame and returns true on OK',
      () async {
        final transport = _RecordingTransport();
        final session = MeshCoreSession(transport);
        final container = _buildContainer(session: session);
        addTearDown(container.dispose);

        // Simulate firmware OK once for the SET_CHANNEL, then keep
        // nodding OK so the post-ACK refresh's getChannels poll loop
        // doesn't hang. getChannels iterates 8 slots and we send OK
        // for each.
        Future.microtask(() async {
          for (var i = 0; i < 9; i++) {
            transport.simulateOk();
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });

        final notifier = container.read(meshCoreChannelsProvider.notifier);
        final ok = await notifier.addChannel(
          index: 2,
          name: 'TestSlot',
          psk: Uint8List.fromList(List.generate(16, (i) => i + 1)),
        );

        expect(ok, isTrue);
        // First sent frame is the SET_CHANNEL. Pin its shape; later
        // frames are getChannels' GET_CHANNEL polls (refresh).
        final setFrame = transport.sent.first;
        expect(setFrame[0], MeshCoreCommands.setChannel);
        expect(setFrame.length, 50, reason: 'Wire frame is exactly 50 bytes');
        expect(setFrame[1], 2, reason: 'slot index byte');

        await session.dispose();
        await transport.dispose();
      },
    );

    test('returns false on firmware timeout (no OK ack)', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      final container = _buildContainer(session: session);
      addTearDown(container.dispose);

      // No OK simulated — the underlying setChannel times out.
      // Provider must return false; no refresh fires (empty Sent at
      // most has the 1 SET_CHANNEL we just attempted).
      final notifier = container.read(meshCoreChannelsProvider.notifier);
      final ok = await notifier.addChannel(
        index: 0,
        name: 'NoAck',
        psk: Uint8List(16),
      );
      expect(ok, isFalse);

      // Local state must be empty (we started disconnected and the
      // failed write doesn't optimistically populate state).
      final state = container.read(meshCoreChannelsProvider);
      expect(state.channels, isEmpty);

      await session.dispose();
      await transport.dispose();
    });
  });

  group('MeshCoreChannelsNotifier.editChannel (D31 Part B)', () {
    test('fires the same CMD_SET_CHANNEL wire op as addChannel '
        '(firmware has no edit-vs-add distinction)', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      final container = _buildContainer(session: session);
      addTearDown(container.dispose);

      Future.microtask(() async {
        for (var i = 0; i < 9; i++) {
          transport.simulateOk();
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      final notifier = container.read(meshCoreChannelsProvider.notifier);
      final ok = await notifier.editChannel(
        index: 4,
        name: 'Edited',
        psk: Uint8List.fromList(List.generate(16, (i) => 0xCC)),
      );
      expect(ok, isTrue);
      expect(transport.sent.first[0], MeshCoreCommands.setChannel);
      expect(transport.sent.first[1], 4);

      await session.dispose();
      await transport.dispose();
    });
  });

  group('MeshCoreChannelsNotifier.removeChannel (D31 Part B)', () {
    test('emits empty-set wire frame: 50 bytes, idx + zeros', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      final container = _buildContainer(session: session);
      addTearDown(container.dispose);

      Future.microtask(() async {
        for (var i = 0; i < 9; i++) {
          transport.simulateOk();
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      final notifier = container.read(meshCoreChannelsProvider.notifier);
      final ok = await notifier.removeChannel(index: 6);
      expect(ok, isTrue);

      final wire = transport.sent.first;
      expect(wire[0], MeshCoreCommands.setChannel);
      expect(wire.length, 50);
      expect(wire[1], 6);
      for (var i = 2; i < 50; i++) {
        expect(wire[i], 0, reason: 'remove frame must be all zeros after idx');
      }

      await session.dispose();
      await transport.dispose();
    });

    test('rejects invalid slot index BEFORE wire op', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      final container = _buildContainer(session: session);
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreChannelsProvider.notifier);
      expect(await notifier.removeChannel(index: -1), isFalse);
      expect(await notifier.removeChannel(index: 256), isFalse);
      expect(transport.sent, isEmpty);

      await session.dispose();
      await transport.dispose();
    });
  });

  group('MeshCoreChannelsNotifier.setChannel back-compat (D31 Part B)', () {
    test('setChannel(MeshCoreChannel) still works as the existing '
        'MeshCoreChannel-model write entry point', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      final container = _buildContainer(session: session);
      addTearDown(container.dispose);

      Future.microtask(() async {
        for (var i = 0; i < 9; i++) {
          transport.simulateOk();
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      final notifier = container.read(meshCoreChannelsProvider.notifier);
      final ok = await notifier.setChannel(
        MeshCoreChannel(index: 1, name: 'BackCompat', psk: Uint8List(16)),
      );
      expect(ok, isTrue);
      expect(transport.sent.first[0], MeshCoreCommands.setChannel);
      expect(transport.sent.first[1], 1);

      await session.dispose();
      await transport.dispose();
    });
  });
}
