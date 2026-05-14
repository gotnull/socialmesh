// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D47-A: `MeshCoreSession.getAutoAddConfig` / `setAutoAddConfig`
// integration pins.
//
// Pinned invariants:
//   - getAutoAddConfig wire payload is `[0x3B]` (no payload);
//     RESP_CODE_AUTO_ADD_CONFIG 0x19 + [flags] → returns parsed
//     config; timeout / empty payload → null.
//   - setAutoAddConfig wire payload is `[0x3A][flags:1B]`;
//     RESP_CODE_OK → true; RESP_CODE_ERR / timeout → false.
//   - Round-trip: get-then-set-with-modified-flags drives a wire
//     write with the expected flag byte.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/models/meshcore_auto_add_config.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _RecordingTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => _connected;

  void inject(Uint8List bytes) {
    _rx.add(bytes);
  }

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

void main() {
  group('D47-A: getAutoAddConfig', () {
    test('wire payload is [0x3B] (no body)', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getAutoAddConfig(
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);

      expect(tx.sent, hasLength(1));
      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sent.command, MeshCoreCommands.getAutoAddConfig);
      expect(sent.payload, isEmpty);

      // Let the request time out so the test completes cleanly.
      expect(await fut, isNull);
    });

    test(
      'RESP_CODE_AUTO_ADD_CONFIG + [flags] → returns parsed config',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final fut = session.getAutoAddConfig();
        await Future<void>.delayed(Duration.zero);

        // 0x06 = chat (0x02) + repeater (0x04).
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.autoAddConfig,
            payload: Uint8List.fromList([0x06]),
          ).toBytes(),
        );
        final config = await fut;
        expect(config, isNotNull);
        expect(config!.autoAddChat, isTrue);
        expect(config.autoAddRepeater, isTrue);
        expect(config.autoAddRoomServer, isFalse);
        expect(config.autoAddSensor, isFalse);
        expect(config.overwriteOldest, isFalse);
      },
    );

    test('reserved bits in response flow through reservedBits', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getAutoAddConfig();
      await Future<void>.delayed(Duration.zero);
      // 0x82 = chat (0x02) + reserved (0x80).
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.autoAddConfig,
          payload: Uint8List.fromList([0x82]),
        ).toBytes(),
      );
      final config = await fut;
      expect(config!.reservedBits, 0x80);
      expect(config.autoAddChat, isTrue);
    });

    test('empty response payload returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getAutoAddConfig();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.autoAddConfig,
          payload: Uint8List(0),
        ).toBytes(),
      );
      expect(await fut, isNull);
    });

    test('timeout returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final config = await session.getAutoAddConfig(
        timeout: const Duration(milliseconds: 200),
      );
      expect(config, isNull);
    });
  });

  group('D47-A: setAutoAddConfig', () {
    test('wire payload is [0x3A][flags]; RESP_CODE_OK → true', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      const config = MeshCoreAutoAddConfig(
        autoAddChat: true,
        autoAddRepeater: true,
        overwriteOldest: true,
      );
      final fut = session.setAutoAddConfig(config);
      await Future<void>.delayed(Duration.zero);

      expect(tx.sent, hasLength(1));
      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sent.command, MeshCoreCommands.setAutoAddConfig);
      // 0x01 (overwrite) + 0x02 (chat) + 0x04 (repeater) = 0x07.
      expect(sent.payload, equals([0x07]));

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.ok,
          payload: Uint8List(0),
        ).toBytes(),
      );
      expect(await fut, isTrue);
    });

    test('reservedBits flow through onto the wire', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      const config = MeshCoreAutoAddConfig(
        autoAddChat: true,
        reservedBits: 0x40,
      );
      final fut = session.setAutoAddConfig(
        config,
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      // 0x02 (chat) | 0x40 (reserved) = 0x42.
      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sent.payload, equals([0x42]));
      // Let the request time out so the test completes cleanly.
      expect(await fut, isFalse);
    });

    test('RESP_CODE_ERR returns false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.setAutoAddConfig(
        const MeshCoreAutoAddConfig(autoAddSensor: true),
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.err,
          payload: Uint8List(0),
        ).toBytes(),
      );
      expect(await fut, isFalse);
    });

    test('timeout returns false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final ok = await session.setAutoAddConfig(
        const MeshCoreAutoAddConfig(autoAddChat: true),
        timeout: const Duration(milliseconds: 200),
      );
      expect(ok, isFalse);
    });
  });

  group('D47-A: get + set round-trip', () {
    test(
      'get → modify → set drives a wire write with the expected flag byte',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        // Step 1: get current config (0x06 = chat + repeater).
        final getFut = session.getAutoAddConfig();
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.autoAddConfig,
            payload: Uint8List.fromList([0x06]),
          ).toBytes(),
        );
        final current = await getFut;
        expect(current, isNotNull);

        // Step 2: flip the chat bit off, send via set.
        final next = current!.copyWith(autoAddChat: false);
        final setFut = session.setAutoAddConfig(next);
        await Future<void>.delayed(Duration.zero);

        final setFrame = MeshCoreFrame.fromBytes(tx.sent.last);
        expect(setFrame.command, MeshCoreCommands.setAutoAddConfig);
        // After flipping chat off: only repeater = 0x04.
        expect(setFrame.payload, equals([0x04]));

        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.ok,
            payload: Uint8List(0),
          ).toBytes(),
        );
        expect(await setFut, isTrue);
      },
    );
  });
}
